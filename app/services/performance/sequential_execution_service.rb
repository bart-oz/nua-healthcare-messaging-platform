# frozen_string_literal: true

# Sequential performance check for Solid Stack + Database
# Only tests pure messaging performance with existing users
class Performance::SequentialExecutionService < Performance::BaseService
  # Main method - always uses pure messaging (existing users only)
  def self.run(users: 100, messages: 10)
    new.check_messaging_only(users, messages)
  end

  # Pure messaging performance test with existing users
  def check_messaging_only(users_count, messages_count)
    puts ""
    puts "🚀 SEQUENTIAL Performance Check: #{users_count} users × #{messages_count} messages"
    puts "   (Note: Pure message sending performance with existing users)"
    puts "=" * 60

    # Setup: Ensure we have enough existing users (outside of timing)
    solid_stack_works = test_solid_stack
    existing_users = get_existing_users(users_count, "PerfTest")

    if existing_users.size < users_count
      puts "⚠️  Need #{users_count} existing users, found #{existing_users.size}. Creating missing users..."
      setup_existing_users(users_count, "PerfTest")
      existing_users = get_existing_users(users_count, "PerfTest")
    end

    puts "✅ Using #{existing_users.size} existing users for pure messaging test"
    puts ""

    # START TIMING: Only message sending operations
    start_time = Time.current
    start_memory = get_memory_usage
    start_cpu = get_cpu_time

    # Pure message sending performance test
    results = send_messages(existing_users, messages_count)

    # END TIMING
    total_time = Time.current - start_time
    end_memory = get_memory_usage
    end_cpu = get_cpu_time
    memory_used = end_memory - start_memory
    cpu_used = end_cpu - start_cpu

    # Cleanup only messages (keep users for future tests)
    cleanup_messages_only(existing_users)

    # Show results
    show_results(users_count, messages_count, solid_stack_works, results, total_time, memory_used, cpu_used)

    # Return results hash
    {
      users: users_count,
      messages_per_user: messages_count,
      time_seconds: total_time.round(2),
      solid_stack_working: solid_stack_works,
      messages_sent: results[:sent],
      expected_messages: users_count * messages_count,
      pure_messaging_rate: (results[:sent] / total_time).round(2),
      success: results[:sent] == (users_count * messages_count)
    }
  end

  private

  def send_messages(users, count_per_user)
    puts "📨 Sending messages sequentially..."

    sent = 0
    failed = 0

    users.each_with_index do |user, i|
      count_per_user.times do |j|
        begin
          params = MessageParams.new(
            body: "Sequential test #{i}-#{j}",
            request_user: user
          )
          service = Messages::Operations::SendService.new(params, user)
          sent += 1 if service.call
        rescue
          failed += 1
        end
      end
    end

    puts "📨 Sent #{sent} messages (#{failed} failed)"
    puts ""
    { sent: sent, failed: failed }
  end

  def show_results(users, messages_per_user, solid_stack_works, results, total_time, memory_used = 0, cpu_used = 0)
    expected = users * messages_per_user
    rate = (results[:sent] / total_time).round(1)

    puts "=" * 60
    puts "📊 SEQUENTIAL MESSAGING RESULTS"
    puts "⏱️  #{total_time.round(2)}s  |  🔧 Solid Stack: #{solid_stack_works ? '✅' : '❌'}  |  📨 #{results[:sent]}/#{expected}"
    puts ""
    puts "🚀 #{rate} messages/sec (pure messaging performance)"
    puts "📅 ~#{format_capacity(rate)} messages/day capacity"

    if memory_used > 0 && results[:sent] > 0
      memory_per_msg = memory_used / results[:sent]
      puts "💾 #{format_memory(memory_used)} memory (#{memory_per_msg.round(2)}MB per message)"
    end

    if cpu_used > 0
      cpu_percentage = (cpu_used / total_time * 100).round(1)
      cpu_cores_used = (cpu_percentage / 100.0).round(1)
      puts "💻 #{cpu_percentage}% CPU usage (~#{cpu_cores_used} cores)"
    end

    if results[:failed] > 0
      puts "⚠️  #{results[:failed]} failed"
    end

    success = results[:failed] == 0
    puts success ? "✅ All transactions completed" : "⚠️  Partial success"
    puts ""
    puts "=" * 60
    puts ""
  end
end
