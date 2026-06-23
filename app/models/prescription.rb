# frozen_string_literal: true

# Represents prescription requests in the medical communication system.
# Handles lost prescription workflows with payment processing and admin generation.
class Prescription < ApplicationRecord
  # == Associations ==
  belongs_to :user
  belongs_to :payment, optional: true
  has_many :messages, dependent: :nullify

  # == Enums ==
  enum :status, { requested: 0, payment_rejected: 1, ready: 2 }

  # == Validations ==
  validates :requested_at, presence: true
  validates :pdf_url, presence: true, if: :ready?
  validates :ready_at, presence: true, if: :ready?

  # == Scopes ==
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :pending_payment, -> { where(status: :requested) }
  scope :failed_payment, -> { where(status: :payment_rejected) }

  # == Instance Methods ==

  # Check if prescription is downloadable
  def downloadable?
    ready? && pdf_url.present?
  end

  # Check if prescription can be retried after Active Job retries failed.
  def retryable?
    payment_rejected? && payment&.failed?
  end

  # Check if payment is still being processed (auto-retries)
  def processing?
    requested? && payment&.pending?
  end

  # Get status badge color for UI
  def status_badge_color
    case status
    when 'requested' then 'warning'
    when 'payment_rejected' then 'danger'
    when 'ready' then 'success'
    end
  end

  # Get status icon for UI
  def status_icon
    case status
    when 'requested' then 'clock'
    when 'payment_rejected' then 'x-circle-fill'
    when 'ready' then 'check-circle-fill'
    end
  end

  # Mark prescription as ready with PDF
  def mark_as_ready!(pdf_url)
    update!(
      status: :ready,
      pdf_url: pdf_url,
      ready_at: Time.current
    )
  end

  # Mark prescription payment as rejected
  def mark_payment_rejected!(error_message = nil)
    update!(status: :payment_rejected)
    payment&.update(error_message: error_message) if error_message
  end

  # == Class Methods ==

  class << self
    # Create new prescription request with payment
    def create_request_for_user(user, payment)
      prescription = create!(
        user: user,
        payment: payment,
        status: :requested,
        requested_at: Time.current
      )

      # Broadcast new prescription to user's list
      Broadcasting::PrescriptionUpdatesService.broadcast_prescription_added(prescription)

      prescription
    end

    # Find retryable prescriptions for user
    def retryable_for_user(user)
      for_user(user).failed_payment.joins(:payment)
                    .where(payments: { retry_count: ...5 })
    end
  end
end

# == Schema Information
#
# Table name: prescriptions
#
#  id           :uuid             not null, primary key
#  pdf_url      :string
#  ready_at     :datetime
#  requested_at :datetime         not null
#  status       :integer          default("requested"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  payment_id   :uuid
#  user_id      :uuid             not null
#
# Indexes
#
#  idx_prescriptions_user_status_created          (user_id,status,created_at)
#  index_prescriptions_on_payment_id              (payment_id)
#  index_prescriptions_on_requested_at            (requested_at)
#  index_prescriptions_on_status                  (status)
#  index_prescriptions_on_user_id                 (user_id)
#  index_prescriptions_on_user_id_and_created_at  (user_id,created_at)
#  index_prescriptions_on_user_id_and_status      (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (payment_id => payments.id)
#  fk_rails_...  (user_id => users.id)
#
