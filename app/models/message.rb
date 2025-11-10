# frozen_string_literal: true

# Represents a message in the medical communication system.
# Handles message threading, status management, and routing logic.
class Message < ApplicationRecord
  include ActionView::RecordIdentifier

  # == Associations ==
  belongs_to :inbox
  belongs_to :outbox
  belongs_to :parent_message, class_name: 'Message', optional: true
  belongs_to :prescription, optional: true
  has_many :replies, class_name: 'Message', foreign_key: 'parent_message_id',
                     dependent: :nullify, inverse_of: :parent_message

  # == Delegations ==
  delegate :user, to: :inbox, prefix: :recipient
  delegate :user, to: :outbox, prefix: :sender

  # == Decorator ==
  def decorate
    Messages::BaseDecorator.new(self)
  end

  # == Enums ==
  enum :status, { sent: 0, delivered: 1, read: 2 }
  enum :routing_type, { direct: 0, reply: 1, auto: 2 }

  # == Validations ==
  validates :body, presence: true, length: { minimum: 1, maximum: 500 }
  validates :status, presence: true
  validates :routing_type, presence: true

  # == Callbacks ==
  # Use background jobs for broadcasting to improve performance
  after_create_commit :enqueue_broadcast_message
  after_update_commit :enqueue_broadcast_update

  # Unread count management (async for performance)
  after_create_commit :enqueue_increment_inbox_unread_count
  after_update_commit :enqueue_handle_read_status_change, if: :saved_change_to_read?

  # Cache invalidation (selective - only when necessary)
  after_commit :invalidate_conversation_caches, on: %i[create update], if: :should_invalidate_caches?

  # == Scopes ==
  scope :unread, -> { where(read: false) }
  scope :recent, -> { where('created_at > ?', 1.week.ago) }

  # Scope for paginated list views - minimal data (no replies)
  scope :with_basic_data, lambda {
    includes(:outbox, :parent_message, outbox: :user, inbox: :user)
  }

  # Scope for detail views - full conversation data
  scope :with_full_conversation, lambda {
    includes(:outbox, :parent_message, :replies,
             outbox: :user, inbox: :user,
             parent_message: %i[inbox outbox],
             replies: %i[inbox outbox])
  }

  # Scope for prescription context
  scope :with_prescriptions, lambda {
    includes(:prescription, prescription: :payment)
  }

  # Combined: full conversation with prescriptions
  scope :with_full_context, lambda {
    with_full_conversation.with_prescriptions
  }

  # == Class Methods ==

  class << self
    # Query interface for message operations
    def query
      MessageQuery.new(self)
    end
  end

  # == Instance Methods ==

  # Check if message is read (avoids Rails method naming conflicts with 'read' column)
  def read_already?
    read
  end

  # == Status Operations (delegated to actions service) ==

  # Mark message as read (force) - raises error for invalid transitions
  def mark_as_read!
    Messages::Operations::ActionsService.mark_as_read!(self)
  end

  # Mark message as read (safe) - returns false for invalid transitions
  def mark_as_read
    Messages::Operations::ActionsService.mark_as_read(self)
  end

  # Mark message as delivered (force) - raises error for invalid transitions
  def mark_as_delivered!
    Messages::Operations::ActionsService.mark_as_delivered!(self)
  end

  # Mark message as delivered (safe) - returns false for invalid transitions
  def mark_as_delivered
    Messages::Operations::ActionsService.mark_as_delivered(self)
  end

  # == Routing Operations (delegated to service) ==

  # Determine routing type based on message context
  def determine_routing_type
    Messages::Operations::RoutingService.determine_routing_type(self)
  end

  # == Broadcasting Operations (direct service calls) ==

  def broadcast_new_message
    Broadcasting::MessageDeliveryService.broadcast_new_message(self)
  end

  def broadcast_update
    Broadcasting::MessageStatusService.broadcast_status_update(self)
  end

  # == Conversation Operations (memoized service calls) ==

  # Get conversation root message
  def conversation_root
    conversation_service.root
  end

  # Get conversation owner (who started the conversation)
  def conversation_owner
    conversation_service.owner
  end

  # Get all messages in the conversation
  def conversation_messages
    conversation_service.messages
  end

  # Get conversation participants
  def conversation_participants
    conversation_service.participants
  end

  # Check if message is part of a threaded conversation
  delegate :threaded?, to: :conversation_service

  # Get conversation statistics
  def conversation_stats
    conversation_service.stats
  end

  # Find doctor in conversation
  def conversation_doctor
    participant_service.first_doctor
  end

  # == Private Methods ==

  private

  # == Memoized Service Accessors ==

  # Memoized conversation service - single instance per message
  def conversation_service
    @conversation_service ||= Messages::Conversations::DataService.new(self)
  end

  # Memoized participant service - single instance per message
  def participant_service
    @participant_service ||= Messages::Participants::DataService.new(conversation_service.messages)
  end

  # Enqueue background job for broadcasting new message
  def enqueue_broadcast_message
    BroadcastMessageJob.perform_later(id)
  end

  # Enqueue background job for broadcasting message update
  def enqueue_broadcast_update
    BroadcastUpdateJob.perform_later(id)
  end

  # Keep original methods for direct use when needed (now using global services)
  def broadcast_message
    broadcast_new_message
  end

  # == Unread Count Management (Async) ==

  # Enqueue background job to increment inbox unread count when new message is created
  def enqueue_increment_inbox_unread_count
    return if inbox.blank?

    UnreadCountUpdateJob.perform_later(inbox.id, 'increment')
  end

  # Enqueue background job to handle read status changes
  def enqueue_handle_read_status_change
    return if inbox.blank?

    inbox_id = inbox.id
    operation = read? ? 'decrement' : 'increment'
    UnreadCountUpdateJob.perform_later(inbox_id, operation)
  end

  # Check if message is unread
  def unread?
    !read?
  end

  # Get time when message was read
  def read_time
    read_at
  end

  # Check if message was read recently (within specified time)
  def read_recently?(within: 1.hour)
    read? && read_at.present? && read_at > within.ago
  end

  # == Cache Operations (delegated to caching service) ==

  # Invalidate conversation caches when messages change
  def invalidate_conversation_caches
    Messages::Caching::InvalidationService.invalidate_conversation_caches(self)
  end

  # Determine if cache invalidation is necessary (performance optimization)
  def should_invalidate_caches?
    # Only invalidate caches for significant changes that affect conversation display
    return true if new_record? # Always invalidate for new messages

    # For updates, only invalidate if content or status changed
    saved_change_to_body? || saved_change_to_status? || saved_change_to_read?
  end
end

# == Schema Information
#
# Table name: messages
#
#  id                :uuid             not null, primary key
#  body              :text
#  read              :boolean          default(FALSE), not null
#  read_at           :datetime
#  routing_type      :integer          default("direct"), not null
#  status            :integer          default("sent"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  inbox_id          :uuid
#  outbox_id         :uuid
#  parent_message_id :uuid
#  prescription_id   :uuid
#
# Indexes
#
#  idx_messages_inbox_created_at                     (inbox_id,created_at DESC)
#  idx_messages_inbox_prescription_created           (inbox_id,prescription_id,created_at)
#  idx_messages_inbox_unread                         (inbox_id,read_at) WHERE (read_at IS NULL)
#  idx_messages_inbox_unread_created                 (inbox_id,read,created_at DESC)
#  idx_messages_outbox_created_at                    (outbox_id,created_at DESC)
#  idx_messages_parent_thread                        (parent_message_id,created_at DESC)
#  idx_messages_root_conversations                   (parent_message_id,created_at DESC) WHERE (parent_message_id IS NULL)
#  idx_messages_status_read                          (status,read)
#  index_messages_on_prescription_id                 (prescription_id)
#  index_messages_on_prescription_id_and_created_at  (prescription_id,created_at)
#  index_messages_on_routing_type                    (routing_type)
#  index_messages_on_routing_type_and_created_at     (routing_type,created_at)
#  index_messages_on_status_and_created_at           (status,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (parent_message_id => messages.id) ON DELETE => nullify
#  fk_rails_...  (prescription_id => prescriptions.id)
#
