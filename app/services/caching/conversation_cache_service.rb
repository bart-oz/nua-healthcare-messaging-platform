# frozen_string_literal: true

module Caching
  # Caches conversation lists and metadata for improved performance
  # Handles conversation lists, recent conversations, and participant info
  class ConversationCacheService
    CACHE_TTL = 30.minutes
    CACHE_KEY_PREFIX = 'conversation'
    MAX_CONVERSATIONS = 50

    class << self
      # Get cached conversation list for a user
      def get_conversation_list(user_id, limit: 20, offset: 0)
        cache_key = "#{CACHE_KEY_PREFIX}:list:#{user_id}:#{limit}:#{offset}"

        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
          fetch_conversation_list_from_db(user_id, limit, offset)
        end
      rescue StandardError => e
        Rails.logger.error "Cache error in conversation list: #{e.message}"
        fetch_conversation_list_from_db(user_id, limit, offset)
      end

      # Cache conversation list for a user
      def cache_conversation_list(user_id, conversations, limit: 20, offset: 0)
        cache_key = "#{CACHE_KEY_PREFIX}:list:#{user_id}:#{limit}:#{offset}"
        Rails.cache.write(cache_key, conversations, expires_in: CACHE_TTL)
      rescue StandardError => e
        Rails.logger.error "Cache error caching conversation list: #{e.message}"
        false
      end

      # Get cached recent conversations for a user
      def get_recent_conversations(user_id, limit: 10)
        cache_key = "#{CACHE_KEY_PREFIX}:recent:#{user_id}:#{limit}"

        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
          fetch_recent_conversations_from_db(user_id, limit)
        end
      rescue StandardError => e
        Rails.logger.error "Cache error in recent conversations: #{e.message}"
        fetch_recent_conversations_from_db(user_id, limit)
      end

      # Cache recent conversations for a user
      def cache_recent_conversations(user_id, conversations, limit: 10)
        cache_key = "#{CACHE_KEY_PREFIX}:recent:#{user_id}:#{limit}"
        Rails.cache.write(cache_key, conversations, expires_in: CACHE_TTL)
      rescue StandardError => e
        Rails.logger.error "Cache error caching recent conversations: #{e.message}"
        false
      end

      # Invalidate conversation cache for a user
      def invalidate_user_conversations(user_id)
        pattern = "#{CACHE_KEY_PREFIX}:*:#{user_id}:*"
        delete_matched(pattern)
      rescue StandardError => e
        Rails.logger.error "Cache error invalidating conversations: #{e.message}"
        false
      end

      # Invalidate all conversation caches
      def invalidate_all_conversations
        pattern = "#{CACHE_KEY_PREFIX}:*"
        delete_matched(pattern)
      rescue StandardError => e
        Rails.logger.error "Cache error invalidating all conversations: #{e.message}"
        false
      end

      # Get cache statistics
      def cache_stats
        {
          cache_ttl: CACHE_TTL,
          max_conversations: MAX_CONVERSATIONS,
          cache_key_prefix: CACHE_KEY_PREFIX
        }
      end

      private

      def fetch_conversation_list_from_db(user_id, limit, offset)
        user = User.find(user_id)
        inbox = user.inbox

        # Get conversations with last message info using ORM
        base_query = Message.joins(:inbox, :outbox)
        conversations_query = base_query.where(inbox: inbox)
                                        .or(base_query.where(outbox: user.outbox))
                                        .order(created_at: :desc)
                                        .limit(limit)
                                        .offset(offset)
                                        .includes(:inbox, :outbox, :parent_message)

        conversations_query.map { |msg| conversation_data(msg) }
                           .uniq { |conv| conv[:conversation_id] }
      end

      def delete_matched(pattern)
        Rails.cache.delete_matched(pattern)
        true
      rescue NoMethodError, NotImplementedError => e
        Rails.logger.warn "Cache store does not support delete_matched: #{e.message}"
        false
      end

      def fetch_recent_conversations_from_db(user_id, limit)
        user = User.find(user_id)
        inbox = user.inbox

        # Get recent conversations with unread counts using ORM
        base_query = Message.joins(:inbox, :outbox)
        conversations_query = base_query.where(inbox: inbox)
                                        .or(base_query.where(outbox: user.outbox))
                                        .order(created_at: :desc)
                                        .limit(limit * 2) # Get more to account for uniq filtering
                                        .includes(:inbox, :outbox, :parent_message)

        conversations_query.map { |msg| recent_conversation_data(msg) }
                           .uniq { |conv| conv[:conversation_id] }
                           .first(limit)
      end

      def conversation_data(message)
        {
          id: message.id,
          conversation_id: conversation_identifier(message),
          last_message: message.body,
          last_message_at: message.created_at,
          participants: extract_participants(message),
          unread_count: calculate_unread_count(message),
          parent_message_id: message.parent_message_id
        }
      end

      def recent_conversation_data(message)
        conversation_data(message).merge(
          preview: message.body.truncate(50),
          has_unread: calculate_unread_count(message).positive?
        )
      end

      def conversation_identifier(message)
        # Create consistent conversation ID regardless of sender/recipient
        [message.inbox_id, message.outbox_id].sort.join('-')
      end

      def extract_participants(message)
        inbox_user = message.inbox.user
        outbox_user = message.outbox.user

        participants = []
        participants << inbox_user unless inbox_user == outbox_user
        participants << outbox_user
        participants.uniq.map { |user| { id: user.id, name: "#{user.first_name} #{user.last_name}" } }
      end

      def calculate_unread_count(message)
        # Count unread messages in this conversation using ORM
        inbox_id = message.inbox_id
        outbox_id = message.outbox_id

        Message.where(
          inbox_id: [inbox_id, outbox_id],
          outbox_id: [inbox_id, outbox_id],
          read: false
        ).count
      end
    end
  end
end
