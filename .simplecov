# frozen_string_literal: true

require 'simplecov'

SimpleCov.start 'rails' do
  # Add any custom groups here
  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Helpers', 'app/helpers'
  add_group 'Services', 'app/services'
  add_group 'Jobs', 'app/jobs'
  add_group 'Mailers', 'app/mailers'
  add_group 'Libraries', 'lib'

  # Set minimum coverage threshold
  minimum_coverage 90

  # Exclude certain files from coverage
  add_filter '/bin/'
  add_filter '/db/'
  add_filter '/spec/'
  add_filter '/test/'
  add_filter '/features/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter '/lib/tasks/'
  add_filter '/lib/generators/'
  add_filter '/app/services/performance/' # Performance testing services

  # Track coverage for specific file types
  track_files 'app/**/*.rb'
  track_files 'lib/**/*.rb'
end
