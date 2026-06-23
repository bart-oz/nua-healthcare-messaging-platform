# frozen_string_literal: true

# Background job for processing prescription payments with retry logic.
# Handles payment processing, retry delays, and admin notifications.
class PrescriptionPaymentJob < ApplicationJob
  queue_as :default

  # Retry configuration: 3 attempts with 10 second intervals
  retry_on Payments::FlakyPaymentProvider::PaymentError,
           wait: 10.seconds,
           attempts: 3

  # Handle final failure after all retries exhausted
  discard_on Payments::FlakyPaymentProvider::PaymentError do |job, exception|
    payment_id = job.arguments.first
    payment = Payment.find_by(id: payment_id)

    if payment
      Rails.logger.warn "All retries exhausted for payment #{payment_id}, marking as failed"
      job_instance = new
      job_instance.send(:handle_payment_failure, payment, exception.message)
    end
  end

  # Process payment for prescription request
  # @param payment_id [String] The ID of the payment to process
  def perform(payment_id)
    payment = Payment.find_by(id: payment_id)
    return unless payment

    logger.info "Processing payment #{payment_id}"

    process_payment(payment)

    logger.info "Successfully processed payment #{payment_id}"
  rescue Payments::FlakyPaymentProvider::PaymentError => e
    logger.warn "Payment failed for #{payment_id}: #{e.message} (attempt #{executions}/3)"
    raise # Re-raise for Active Job retry
  rescue StandardError => e
    logger.error "Unexpected error processing payment #{payment_id}: #{e.message}"
    raise # Re-raise for Active Job retry
  end

  private

  # Process payment using payment provider
  def process_payment(payment)
    provider = Payments::PaymentProviderFactory.provider

    result = provider.debit(payment.amount, payment_id: payment.id)

    raise Payments::FlakyPaymentProvider::PaymentError, 'Payment provider returned false' unless result

    handle_payment_success(payment)
  end

  # Handle successful payment
  def handle_payment_success(payment)
    payment.mark_completed!

    # Update prescription status
    prescription = payment.prescription
    return unless prescription

    prescription.update!(status: :requested) # Keep as requested until admin generates PDF

    # LOGICAL ORDER: First send admin notification, THEN broadcast to patient
    # This ensures admin gets notified before patient sees "Awaiting Admin approval" status

    # 1. FIRST: Send message to admin about successful payment (creates message)
    notify_admin_of_prescription_request(prescription)

    # 2. SECOND: Broadcast success to patient AFTER admin notification with wait
    broadcast_payment_success(prescription, wait_for_message: true)
  end

  # Handle payment failure
  def handle_payment_failure(payment, error_message)
    payment.mark_failed!(error_message)

    # Update prescription status
    prescription = payment.prescription
    prescription&.mark_payment_rejected!(error_message)

    # Broadcast failure to patient
    broadcast_payment_failure(prescription)
  end

  # Send notification message to admin
  def notify_admin_of_prescription_request(prescription)
    admin = User.admin.first
    return unless admin

    message_body = "Prescription request from #{prescription.user.full_name}. " \
                   "Payment confirmed (€#{prescription.payment.amount}). " \
                   'Please generate and send prescription.'

    # Create message directly to admin inbox with prescription relationship
    message = Message.create!(
      body: message_body,
      status: :sent,
      routing_type: :direct,
      prescription: prescription,
      outbox: prescription.user.outbox,  # From patient
      inbox: admin.inbox                 # Directly to admin
    )

    # Broadcast new message to admin's inbox
    Broadcasting::MessageDeliveryService.broadcast_new_message(message)
  end

  # Broadcast payment success to patient
  def broadcast_payment_success(prescription, wait_for_message: false)
    Broadcasting::PrescriptionUpdatesService.broadcast_status_update(
      prescription,
      I18n.t('prescriptions.notices.payment_success'),
      wait_for_message: wait_for_message
    )
  end

  # Broadcast payment failure to patient
  def broadcast_payment_failure(prescription)
    Broadcasting::PrescriptionUpdatesService.broadcast_status_update(
      prescription,
      I18n.t('prescriptions.notices.payment_failed')
    )
  end
end
