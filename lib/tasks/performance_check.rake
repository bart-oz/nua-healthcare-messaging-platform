# frozen_string_literal: true

desc 'Performance testing: sequential and concurrent (pure messaging only)'
namespace :performance_check do

  # Pure messaging performance tests (existing users only)
  task :sequential, %i[users messages] => :environment do |_t, args|
    users = (args[:users] || 100).to_i
    messages = (args[:messages] || 10).to_i

    verify_solid_stack
    results = Performance::SequentialExecutionService.run(users: users, messages: messages)
    cleanup_solid_queue_jobs
    exit(results[:success] ? 0 : 1)
  end

  task :concurrent, %i[users messages] => :environment do |_t, args|
    users = (args[:users] || 100).to_i
    messages = (args[:messages] || 10).to_i

    verify_solid_stack
    results = Performance::ConcurrentExecutionService.run(users: users, messages: messages)
    cleanup_solid_queue_jobs
    exit(results[:success] ? 0 : 1)
  end

  # Setup existing users for messaging tests
  task :setup_users, %i[count] => :environment do |_t, args|
    count = (args[:count] || 200).to_i

    puts "🔧 Setting up #{count} users for messaging performance tests..."
    service = Performance::BaseService.new
    users = service.setup_existing_users(count, "PerfTest")
    puts "✅ Created #{users.size} users with IDs: #{users.map(&:id).join(', ')}"
    puts "💡 These users are ready for messaging performance tests"
  end

  # Cleanup existing test users
  task :cleanup_test_users => :environment do
    puts "🧹 Cleaning up performance test users..."
    users = User.where("first_name LIKE 'PerfTest%' OR first_name LIKE 'Sequential%' OR first_name LIKE 'Concurrent%'")
    count = users.count

    users.find_each do |user|
      Message.joins(:inbox).where(inboxes: { user_id: user.id }).delete_all
      user.inbox&.destroy
      user.outbox&.destroy
      user.destroy
    end

    puts "✅ Removed #{count} test users and their messages"
  end

  # Clear all Solid Queue jobs (useful after performance tests)
  task :clear_jobs => :environment do
    puts "🧹 Clearing all Solid Queue jobs..."

    cleanup_solid_queue_jobs
  end

  def verify_solid_stack
    service = Performance::BaseService.new
    unless service.test_solid_stack
      puts "❌ Solid Stack is not ready - prepare queue/cache databases before running performance tests"
      exit(1)
    end

    puts "🎯 Solid Stack ready for performance testing"
  rescue StandardError => e
    puts "📡 Solid Stack error: #{e.message}"
    exit(1)
  end

  # Clear any accumulated jobs after performance testing.
  def cleanup_solid_queue_jobs
    count = defined?(SolidQueue::Job) ? SolidQueue::Job.count : 0
    SolidQueue::Job.delete_all if defined?(SolidQueue::Job)
    puts "🧹 Cleared #{count} Solid Queue jobs"
  rescue StandardError => e
    puts "⚠️  Could not clear Solid Queue jobs: #{e.message}"
  end
end

# Simple aliases
task :sequential, %i[users messages] => 'performance_check:sequential'
task :concurrent, %i[users messages] => 'performance_check:concurrent'

# Default to sequential
task :perform, %i[users messages] => 'performance_check:sequential'

# Examples:
#
# == PURE MESSAGING PERFORMANCE TESTS ==
# rake performance_check:setup_users[200]     # Setup 200 test users first (one-time)
# rake sequential[100,10]                     # Sequential: 100 users, 10 messages (default)
# rake concurrent[100,10]                     # Concurrent: 100 users, 10 messages (default)
# rake sequential[50,5]                       # Sequential: 50 users, 5 messages
# rake concurrent[25,3]                       # Concurrent: 25 users, 3 messages
#
# == CLEANUP ==
# rake performance_check:cleanup_test_users   # Remove all test users
# rake performance_check:clear_jobs           # Clear all Solid Queue jobs
#
# 💡 TIP: Always run setup_users first before running performance tests
# 🚀 All tests now measure PURE messaging performance (no user creation overhead)
# 🧹 Use clear_jobs if you see background job accumulation
