# frozen_string_literal: true

require 'capybara/cucumber'
require 'capybara-screenshot/cucumber'

# Load Rails environment
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __dir__)

# Configure Capybara
Capybara.default_driver = :selenium_chrome_headless
Capybara.javascript_driver = :selenium_chrome_headless

# Configure Capybara to use Rails test server
Capybara.app = Rails.application
Capybara.server = :puma, { Silent: true }

Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1920,1080')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara::Screenshot.register_driver(:selenium_chrome_headless) do |driver, path|
  driver.browser.save_screenshot(path)
end

# Configure screenshot settings
Capybara::Screenshot.autosave_on_failure = true
Capybara::Screenshot.prune_strategy = :keep_last_run
Capybara::Screenshot.append_timestamp = true
Capybara::Screenshot.capybara_tmp_path = Rails.root.join('tmp/capybara')

# Run Active Job work inline during Cucumber flows.
ActiveJob::Base.queue_adapter = :inline
