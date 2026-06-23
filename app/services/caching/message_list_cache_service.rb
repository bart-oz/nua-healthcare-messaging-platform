# frozen_string_literal: true

module Caching
  # Caches message lists and conversation threads for improved performance
  # Handles individual conversation threads, message pagination, and thread ordering
  class MessageListCacheService
    CACHE_TTL = 15.minutes
    CACHE_KEY_PREFIX = 'message_list'
    MAX_MESSAGES_PER_THREAD = 100

    class << self
      # Get cached message list for a conversation
      def get_message_list(conversation_id, limit: 10, offset: 0)
        cache_key = "#{CACHE_KEY_PREFIX}:thread:#{conversation_id}:#{limit}:#{offset}"

        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
          fetch_message_list_from_db(conversation_id, limit, offset)
        end
      rescue StandardError => e
        Rails.logger.error "Cache error in message list: #{e.message}"
        fetch_message_list_from_db(conversation_id, limit, offset)
      end

      # Cache message list for a conversation
      def cache_message_list(conversation_id, messages, limit: 10, offset: 0)
        cache_key = "#{CACHE_KEY_PREFIX}:thread:#{conversation_id}:#{limit}:#{offset}"
        Rails.cache.write(cache_key, messages, expires_in: CACHE_TTL)
      rescue StandardError => e
        Rails.logger.error "Cache error caching message list: #{e.message}"
        false
      end

      # Get cached conversation thread
      def get_conversation_thread(inbox_id, outbox_id, limit: 50)
        conversation_id = conversation_identifier(inbox_id, outbox_id)
        cache_key = "#{CACHE_KEY_PREFIX}:conversation:#{conversation_id}:#{limit}"

        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
          fetch_conversation_thread_from_db(inbox_id, outbox_id, limit)
        end
      rescue StandardError => e
        Rails.logger.error "Cache error in conversation thread: #{e.message}"
        fetch_conversation_thread_from_db(inbox_id, outbox_id, limit)
      end

      # Cache conversation thread
      def cache_conversation_thread(inbox_id, outbox_id, messages, limit: 50)
        conversation_id = conversation_identifier(inbox_id, outbox_id)
        cache_key = "#{CACHE_KEY_PREFIX}:conversation:#{conversation_id}:#{limit}"
        Rails.cache.write(cache_key, messages, expires_in: CACHE_TTL)
      rescue StandardError => e
        Rails.logger.error "Cache error caching conversation thread: #{e.message}"
        false
      end

      # Invalidate message list cache for a conversation
      def invalidate_conversation_cache(inbox_id, outbox_id)
        conversation_id = conversation_identifier(inbox_id, outbox_id)
        pattern = "#{CACHE_KEY_PREFIX}:*:#{conversation_id}:*"
        delete_matched(pattern)
      rescue StandardError => e
        Rails.logger.error "Cache error invalidating conversation: #{e.message}"
        false
      end

      # Invalidate all message list caches
      def invalidate_all_message_lists
        pattern = "#{CACHE_KEY_PREFIX}:*"
        delete_matched(pattern)
      rescue StandardError => e
        Rails.logger.error "Cache error invalidating all message lists: #{e.message}"
        false
      end

      # Get cache statistics
      def cache_stats
        {
          cache_ttl: CACHE_TTL,
          max_messages_per_thread: MAX_MESSAGES_PER_THREAD,
          cache_key_prefix: CACHE_KEY_PREFIX
        }
      end

      private

      def fetch_message_list_from_db(conversation_id, limit, offset)
        # Parse conversation ID to get inbox and outbox IDs
        inbox_id, outbox_id = conversation_id.split('-').map(&:to_s)

        messages = Message.where(
          inbox_id: [inbox_id, outbox_id],
          outbox_id: [inbox_id, outbox_id]
        )
                          .includes(:inbox, :outbox, :parent_message)
                          .order(created_at: :desc)
                          .limit(limit)
                          .offset(offset)
                          .map { |msg| message_data(msg) }

        messages.reverse # Return in chronological order
      end

      def delete_matched(pattern)
        Rails.cache.delete_matched(pattern)
        true
      rescue NoMethodError, NotImplementedError => e
        Rails.logger.warn "Cache store does not support delete_matched: #{e.message}"
        false
      end

      def fetch_conversation_thread_from_db(inbox_id, outbox_id, limit)
        Message.where(
          inbox_id: [inbox_id, outbox_id],
          outbox_id: [inbox_id, outbox_id]
        )
               .includes(:inbox, :outbox, :parent_message)
               .order(created_at: :asc) # Chronological order for conversation view
               .limit(limit)
               .map { |msg| conversation_message_data(msg) }
      end

      def message_data(message)
        inbox_user = message.inbox.user
        outbox_user = message.outbox.user

        {
          id: message.id,
          body: message.body,
          created_at: message.created_at,
          read: message.read,
          read_at: message.read_at,
          status: message.status,
          routing_type: message.routing_type,
          parent_message_id: message.parent_message_id,
          sender: {
            id: outbox_user.id,
            name: "#{outbox_user.first_name} #{outbox_user.last_name}"
          },
          recipient: {
            id: inbox_user.id,
            name: "#{inbox_user.first_name} #{inbox_user.last_name}"
          }
        }
      end

      def conversation_message_data(message)
        created_at = message.created_at

        message_data(message).merge(
          is_sender: message.outbox.user_id == message.inbox.user_id,
          formatted_time: created_at.strftime('%H:%M'),
          formatted_date: created_at.strftime('%b %d')
        )
      end

      def conversation_identifier(inbox_id, outbox_id)
        # Create consistent conversation ID regardless of sender/recipient
        [inbox_id.to_s, outbox_id.to_s].sort.join('-')
      end
    end
  end
end
