# frozen_string_literal: true

# Cache warming service for proactive cache population
# Improves performance by pre-loading frequently accessed data
# Provides intelligent cache warming strategies for optimal performance
module Caching
  class WarmingService
    class << self
      # Warm unread count caches for all active inboxes
      def warm_unread_counts
        return unless cache_available?

        Rails.logger.info '🔥 Warming unread count caches...' unless Rails.env.test?

        # Get all inboxes with recent activity (last 30 days)
        active_inboxes = Inbox.joins(:messages)
                              .where('messages.created_at > ?', 30.days.ago)
                              .distinct
                              .limit(1000) # Limit to prevent memory issues

        warmed_count = 0
        failed_count = 0

        active_inboxes.find_each(batch_size: 100) do |inbox|
          Caching::UnreadCountService.recalculate_and_cache(inbox)
          warmed_count += 1
        rescue StandardError => e
          failed_count += 1
          Rails.logger.error "Failed to warm cache for inbox #{inbox.id}: #{e.message}"
        end

        unless Rails.env.test?
          Rails.logger.debug do
            "✅ Warmed #{warmed_count} unread count caches, #{failed_count} failed"
          end
        end
        { warmed: warmed_count, failed: failed_count }
      end

      # Warm caches for specific user's inbox
      def warm_user_inbox(user)
        return unless cache_available?

        inbox = user.inbox
        return unless inbox

        Caching::UnreadCountService.recalculate_and_cache(inbox)
      end

      # Warm caches for multiple users
      def warm_multiple_users(users)
        return unless cache_available?

        users.each do |user|
          warm_user_inbox(user)
        end
      end

      # Warm conversation caches for active users
      def warm_conversation_caches
        return unless cache_available?

        logger = Rails.logger
        test_env = Rails.env.test?

        logger.info '🔥 Warming conversation caches...' unless test_env

        # Get users with recent message activity
        active_users = User.joins(inbox: :messages)
                           .where('messages.created_at > ?', 7.days.ago)
                           .distinct
                           .limit(500)

        warmed_count = 0
        active_users.find_each(batch_size: 50) do |user|
          user_id = user.id
          # Warm recent conversations
          conversations = Caching::ConversationCacheService.get_recent_conversations(user_id, limit: 10)
          Caching::ConversationCacheService.cache_recent_conversations(user_id, conversations, limit: 10)
          warmed_count += 1
        end

        logger.debug { "✅ Warmed #{warmed_count} conversation caches" } unless test_env
        warmed_count
      end

      # Warm message list caches for active conversations
      def warm_message_list_caches
        return unless cache_available?

        logger = Rails.logger
        test_env = Rails.env.test?

        logger.info '🔥 Warming message list caches...' unless test_env

        # Get recent conversations using ORM
        recent_conversations = Message.joins(:inbox, :outbox)
                                      .where('messages.created_at > ?', 3.days.ago)
                                      .order(created_at: :desc)
                                      .limit(400) # Get more to account for uniq filtering
                                      .map { |msg| msg }
                                      .uniq { |msg| [msg.inbox_id, msg.outbox_id].sort.join('-') }
                                      .first(200)

        warmed_count = 0
        recent_conversations.each do |message|
          inbox_id = message.inbox_id
          outbox_id = message.outbox_id

          Caching::ConversationCacheService.send(:conversation_identifier, message)
          messages = Caching::MessageListCacheService.get_conversation_thread(
            inbox_id, outbox_id, limit: 50
          )
          Caching::MessageListCacheService.cache_conversation_thread(
            inbox_id, outbox_id, messages, limit: 50
          )
          warmed_count += 1
        end

        logger.debug { "✅ Warmed #{warmed_count} message list caches" } unless test_env
        warmed_count
      end

      # Get cache warming statistics
      def warming_stats
        {
          cache_available: cache_available?,
          last_warmed_at: Rails.cache.read('cache_warming:last_run'),
          warmed_count: Rails.cache.read('cache_warming:count') || 0
        }
      end

      # Schedule cache warming (can be called from cron/background job)
      def schedule_warming
        return unless cache_available?

        Rails.cache.write('cache_warming:last_run', Time.current, expires_in: 1.hour)
        result = warm_unread_counts
        warmed_count = result.is_a?(Hash) ? result[:warmed] : result
        Rails.cache.write('cache_warming:count', warmed_count, expires_in: 1.hour)
      end

      private

      def cache_available?
        cache_store = Rails.cache
        cache_store.respond_to?(:read) && cache_store.respond_to?(:write)
      rescue StandardError
        false
      end
    end
  end
end
