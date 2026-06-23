# frozen_string_literal: true

module Messages
  module Caching
    # Handles cache invalidation for message-related operations
    # Integrates with existing caching services for conversation and message list caches
    class InvalidationService
      attr_reader :message

      def initialize(message)
        @message = message
      end

      # == Public Interface ==

      # Invalidate all conversation-related caches when message changes
      def invalidate_conversation_caches
        return if message.inbox.blank? || message.outbox.blank?

        # Invalidate conversation caches for both participants
        ::Caching::ConversationCacheService.invalidate_user_conversations(message.inbox.user_id)
        ::Caching::ConversationCacheService.invalidate_user_conversations(message.outbox.user_id)

        # Invalidate message list caches for this conversation
        ::Caching::MessageListCacheService.invalidate_conversation_cache(message.inbox_id, message.outbox_id)
      rescue StandardError => e
        Rails.logger.error "Message cache invalidation failed: #{e.message}"
      end

      class << self
        # Class method for cache invalidation
        def invalidate_conversation_caches(message)
          new(message).invalidate_conversation_caches
        end
      end
    end
  end
end
