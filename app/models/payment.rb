# frozen_string_literal: true

# Represents payment transactions in the medical communication system.
# Tracks payment status, retry logic, and integrates with various payment providers.
class Payment < ApplicationRecord
  # == Associations ==
  belongs_to :user
  has_one :prescription, dependent: :nullify

  # == Enums ==
  enum :status, { pending: 0, completed: 1, failed: 2, refunded: 3 }

  # == Validations ==
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_provider, presence: true
  validates :retry_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # == Scopes ==
  scope :recent, -> { order(created_at: :desc) }
  scope :for_prescriptions, -> { joins(:prescription) }

  # == Instance Methods ==

  # Mark payment as completed
  def mark_completed!
    update!(status: :completed)
  end

  # Mark payment as failed after Active Job retries are exhausted.
  def mark_failed!(error_message = nil)
    update!(
      status: :failed,
      error_message: error_message,
      retry_count: retry_count + 1
    )
  end

  # == Class Methods ==

  class << self
    # Create new payment for prescription request
    def create_for_prescription(user, amount = 10.0)
      create!(
        user: user,
        amount: amount,
        payment_provider: 'flaky',
        status: :pending
      )
    end
  end
end

# == Schema Information
#
# Table name: payments
#
#  id               :uuid             not null, primary key
#  amount           :decimal(8, 2)    default(0.0), not null
#  error_message    :text
#  last_retry_at    :datetime
#  payment_provider :string           default("flaky"), not null
#  retry_count      :integer          default(0), not null
#  status           :integer          default("pending"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  user_id          :uuid
#
# Indexes
#
#  idx_payments_status_retry_created        (status,retry_count,created_at)
#  idx_payments_user_status_created         (user_id,status,created_at)
#  index_payments_on_retry_count            (retry_count)
#  index_payments_on_status_and_created_at  (status,created_at)
#  index_payments_on_user_id                (user_id)
#  index_payments_on_user_id_and_status     (user_id,status)
#
