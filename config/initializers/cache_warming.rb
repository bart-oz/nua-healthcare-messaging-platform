# frozen_string_literal: true

# Cache Warming Configuration and Scheduling
# Provides automatic cache warming strategies for optimal performance

# Cache warming configuration
CACHE_WARMING_CONFIG = {
  # Enable automatic warming in production
  enabled: Rails.env.production?,

  # Warming intervals (in hours)
  intervals: {
    unread_counts: 6,      # Every 6 hours
    user_specific: 1       # Every hour for active users
  },

  # Limits to prevent memory issues
  limits: {
    max_inboxes_per_batch: 1000,
    max_users_per_batch: 500
  },

  # Time windows for activity-based warming
  activity_windows: {
    recent_activity: 30.days,
    active_user_window: 7.days
  }
}.freeze

# Schedule cache warming on application boot (production only).
# Skip during asset precompilation to avoid database connections during build.
if CACHE_WARMING_CONFIG[:enabled] && !ENV['SECRET_KEY_BASE_DUMMY']
  Rails.application.config.after_initialize do
    # Warm caches on application start
    CacheWarmingJob.perform_later(:unread_counts)

    Rails.logger.info "🔥 Cache warming scheduled for application startup"
  end
end

# Manual cache warming methods for development/testing
module CacheWarming
  class << self
    # Warm all unread count caches
    def warm_all
      Caching::WarmingService.warm_unread_counts
    end

    # Warm caches for specific user
    def warm_user(user)
      Caching::WarmingService.warm_user_inbox(user)
    end

    # Warm caches for multiple users
    def warm_users(users)
      Caching::WarmingService.warm_multiple_users(users)
    end

    # Get warming statistics
    def stats
      Caching::WarmingService.warming_stats
    end

    # Check if warming is enabled
    def enabled?
      CACHE_WARMING_CONFIG[:enabled]
    end
  end
end
