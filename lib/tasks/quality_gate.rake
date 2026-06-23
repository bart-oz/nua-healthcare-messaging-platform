# frozen_string_literal: true

namespace :quality_gate do
  desc 'Run all quality checks (including E2E tests and performance checks)'
  task all: %i[security code_smells style test_coverage e2e_tests translations performance]

  desc 'Run security checks'
  task security: :environment do
    puts '🔒 Running Brakeman...'
    exit_code = system('bundle exec brakeman')
    unless exit_code
      puts '❌ Brakeman found security vulnerabilities. Please address them before committing.'
      exit(1)
    end
    puts '✅ Brakeman passed - no security vulnerabilities found.'
  end

  desc 'Run code smell analysis'
  task code_smells: :environment do
    puts '👃 Running Reek...'
    exit_code = system('bundle exec reek app lib')
    unless exit_code
      puts '❌ Reek found code smells. Please address them before committing.'
      exit(1)
    end
    puts '✅ Reek passed - no code smells detected.'
  end

  desc 'Run code style checks'
  task style: :environment do
    puts '🎨 Running RuboCop...'
    exit_code = system('bundle exec rubocop')
    unless exit_code
      puts '❌ RuboCop found style violations. Please fix them before committing.'
      exit(1)
    end
    puts '✅ RuboCop passed - no style violations found.'
  end

  desc 'Run test coverage'
  task test_coverage: :environment do
    puts '🧪 Running RSpec with coverage...'
    exit_code = system('COVERAGE=true bundle exec rspec --format progress')
    unless exit_code
      puts '❌ Test coverage failed - either tests failed or coverage is below the required minimum (85.00%).'
      exit(1)
    end
    puts '✅ Test coverage passed - all tests passed and coverage meets the minimum requirement (85.00%).'
  end

  desc 'Run E2E tests with Cucumber'
  task e2e_tests: :environment do
    puts '🚀 Running Cucumber E2E tests...'
    exit_code = system('bundle exec cucumber --format progress')
    unless exit_code
      puts '❌ Cucumber E2E tests failed. Please fix them before committing.'
      exit(1)
    end
    puts '✅ Cucumber E2E tests passed.'
  end

  desc 'Check translation consistency'
  task translations: :environment do
    puts '🌍 Checking translations...'
    missing_exit = system('bundle exec i18n-tasks missing')
    unused_exit = system('bundle exec i18n-tasks unused')

    unless missing_exit && unused_exit
      puts '❌ Translation checks failed. Please fix missing or unused translations.'
      exit(1)
    end
    puts '✅ Translation checks passed - no missing or unused translations found.'
  end

  desc 'Run performance benchmark tests'
  task performance: :environment do
    puts '⚡ Running performance benchmarks...'

    puts '🔧 Setting up test users for performance tests...'
    setup_exit = system('RAILS_ENV=development bundle exec rake performance_check:setup_users[100]')
    unless setup_exit
      puts '❌ Performance test user setup failed.'
      exit(1)
    end

    puts '📈 Running sequential messaging performance test...'
    sequential_exit = system('RAILS_ENV=development bundle exec rake sequential[100,10]')
    unless sequential_exit
      puts '❌ Sequential performance test failed.'
      exit(1)
    end

    puts '🔥 Running concurrent messaging performance test...'
    concurrent_exit = system('RAILS_ENV=development bundle exec rake concurrent[100,10]')
    unless concurrent_exit
      puts '❌ Concurrent performance test failed.'
      exit(1)
    end

    puts '✅ All performance benchmarks passed - pure messaging tests successful.'
  end
end
