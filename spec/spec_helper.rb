require 'bundler/setup'
require 'rspec/core'
require 'support/database'
require 'support/latch'

ENV['RACK_ENV'] = 'test'

RSpec.configure do |config|
  config.filter_run :focused => true
  config.run_all_when_everything_filtered = true
  config.alias_example_to :fit, :focused => true

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.mock_with :none
end
