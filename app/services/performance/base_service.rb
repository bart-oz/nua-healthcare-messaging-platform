# frozen_string_literal: true

# Base service for performance testing with shared functionality
class Performance::BaseService
  def test_solid_stack
    test_key = "performance_check:solid_stack"

    Rails.cache.write(test_key, "ok", expires_in: 10.seconds)
    result = Rails.cache.read(test_key) == "ok"
    Rails.cache.delete(test_key)
    result && ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::SolidQueueAdapter)
  rescue StandardError
    false
  end

  def create_users(count, prefix = "Test")
    users = []
    count.times do |i|
      user = User.find_or_create_by(first_name: "#{prefix}#{i}") do |u|
        u.last_name = "User"
        u.is_patient = true
        u.is_doctor = false
        u.is_admin = false
      end
      users << user
    end
    puts ""
    puts "👥 Created #{users.size} users"
    users
  end

  # Pre-create users for existing user scenario testing
  def setup_existing_users(count, prefix = "PerfTest")
    puts "🔧 Setting up existing users for performance testing..."
    users = []
    count.times do |i|
      user = User.find_or_create_by(first_name: "#{prefix}#{i}") do |u|
        u.last_name = "User"
        u.is_patient = true
        u.is_doctor = false
        u.is_admin = false
      end

      # Ensure inbox and outbox exist (triggered by after_create callback)
      user.create_inbox! unless user.inbox
      user.create_outbox! unless user.outbox

      users << user
    end
    puts "✅ Setup complete: #{users.size} existing users ready"
    users
  end

  # NEW: Get existing users by prefix for pure messaging tests
  def get_existing_users(count, prefix = "PerfTest")
    User.where("first_name LIKE ?", "#{prefix}%")
        .includes(:inbox, :outbox)  # Preload associations
        .limit(count)
        .to_a
  end

  def cleanup(users)
    users.each do |user|
      Message.joins(:inbox).where(inboxes: { user_id: user.id }).delete_all
      user.inbox&.destroy
      user.outbox&.destroy
      user.destroy
    end
  end

  # Cleanup only messages for existing user tests
  def cleanup_messages_only(users)
    users.each do |user|
      Message.joins(:inbox).where(inboxes: { user_id: user.id }).delete_all
      user.inbox&.update(unread_count: 0) if user.inbox
    end
  end

  def get_memory_usage
    # Get memory usage in MB
    pid = Process.pid
    memory_kb = `ps -o rss= -p #{pid}`.strip.to_i
    memory_kb / 1024.0
  rescue
    0
  end

  def get_cpu_time
    Process.times.utime + Process.times.stime
  rescue
    0
  end

  def format_memory(mb)
    if mb >= 1024
      "#{(mb / 1024.0).round(1)}GB"
    else
      "#{mb.round(1)}MB"
    end
  end

  def format_capacity(rate)
    daily = (rate * 0.5 * 86_400).to_i
    if daily >= 1_000_000
      "#{(daily / 1_000_000.0).round(1)}M"
    elsif daily >= 1_000
      "#{(daily / 1_000.0).round(0)}K"
    else
      daily.to_s
    end
  end

  # Abstract methods to be implemented by subclasses
  def send_messages(users, count_per_user)
    raise NotImplementedError, "#{self.class} must implement send_messages"
  end

  def show_results(users, messages_per_user, solid_stack_works, results, total_time, memory_used, cpu_used)
    raise NotImplementedError, "#{self.class} must implement show_results"
  end
end
