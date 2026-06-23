# frozen_string_literal: true

# Caching service for unread message counts with smart invalidation
# Maintains real-time updates via Turbo Streams while reducing database load
# Provides cache management for inbox unread counts with fallback to database
module Caching
  class UnreadCountService
    CACHE_TTL = 10.minutes # Increased TTL to reduce cache misses
    CACHE_KEY_PREFIX = 'inbox_unread_count'

    # Connection pool settings retained for cache health monitoring.
    CONNECTION_POOL_SIZE = 5
    CONNECTION_POOL_TIMEOUT = 5

    class << self
      # Get cached unread count for an inbox
      def get_unread_count(inbox)
        return inbox.unread_count unless cache_available?

        cache_key = cache_key_for(inbox)
        cached_count = Rails.cache.read(cache_key)

        if cached_count.nil?
          # Cache miss - fetch from database and cache
          actual_count = fetch_unread_count_from_db(inbox)
          Rails.cache.write(cache_key, actual_count, expires_in: CACHE_TTL)
          cached_count = actual_count
        end

        cached_count
      rescue StandardError
        # Fallback to database if cache is unavailable
        fetch_unread_count_from_db(inbox)
      end

      # Set unread count in cache
      def set_unread_count(inbox, count)
        return unless cache_available?

        cache_key = cache_key_for(inbox)
        Rails.cache.write(cache_key, count, expires_in: CACHE_TTL)
      rescue StandardError
        # Fallback - do nothing, let database handle it
        nil
      end

      # Increment unread count in cache
      def increment_unread_count(inbox)
        return unless cache_available?

        cache_key = cache_key_for(inbox)
        current_count = Rails.cache.read(cache_key) || fetch_unread_count_from_db(inbox)
        new_count = current_count + 1

        Rails.cache.write(cache_key, new_count, expires_in: CACHE_TTL)
        new_count
      rescue StandardError
        # Fallback - just return the incremented database count
        fetch_unread_count_from_db(inbox) + 1
      end

      # Decrement unread count in cache
      def decrement_unread_count(inbox)
        return unless cache_available?

        cache_key = cache_key_for(inbox)
        current_count = Rails.cache.read(cache_key) || fetch_unread_count_from_db(inbox)
        new_count = [current_count - 1, 0].max

        Rails.cache.write(cache_key, new_count, expires_in: CACHE_TTL)
        new_count
      rescue StandardError
        # Fallback - just return the decremented database count
        [fetch_unread_count_from_db(inbox) - 1, 0].max
      end

      # Reset unread count in cache to zero
      def reset_unread_count(inbox)
        return unless cache_available?

        cache_key = cache_key_for(inbox)
        Rails.cache.write(cache_key, 0, expires_in: CACHE_TTL)
      rescue StandardError
        # Fallback - do nothing, let database handle it
        nil
      end

      # Invalidate cache for an inbox (force refresh on next read)
      def invalidate_cache(inbox)
        return unless cache_available?

        cache_key = cache_key_for(inbox)
        Rails.cache.delete(cache_key)
      rescue StandardError
        # Fallback - do nothing
        nil
      end

      # Recalculate and cache unread count from database
      def recalculate_and_cache(inbox)
        return unless cache_available?

        actual_count = fetch_unread_count_from_db(inbox)
        set_unread_count(inbox, actual_count)
        actual_count
      rescue StandardError
        # Fallback - just return the database count
        fetch_unread_count_from_db(inbox)
      end

      # Warm cache for multiple inboxes
      def warm_cache_for_inboxes(inboxes)
        return unless cache_available?

        inboxes.each do |inbox|
          recalculate_and_cache(inbox)
        end
      end

      # Get cache statistics for monitoring
      def cache_stats
        return {} unless cache_available?

        {
          cache_available: true,
          cache_ttl: CACHE_TTL,
          cache_key_prefix: CACHE_KEY_PREFIX
        }
      end

      # Simple cache health check
      def cache_health_check
        return { status: :unavailable } unless cache_available?

        begin
          test_key = "#{CACHE_KEY_PREFIX}:health_check"
          Rails.cache.write(test_key, 'test', expires_in: 1.minute)
          test_value = Rails.cache.read(test_key)
          Rails.cache.delete(test_key)

          test_value == 'test' ? { status: :healthy } : { status: :degraded }
        rescue StandardError => e
          { status: :error, error: e.message }
        end
      end

      private

      def cache_key_for(inbox)
        "#{CACHE_KEY_PREFIX}:#{inbox.id}"
      end

      def fetch_unread_count_from_db(inbox)
        # Count all unread messages including replies - users need to know about new replies
        inbox.messages.unread.count
      end

      def cache_available?
        cache_store = Rails.cache
        cache_store.respond_to?(:read) && cache_store.respond_to?(:write)
      rescue StandardError
        false
      end
    end
  end
end
