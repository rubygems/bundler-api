require 'rspec/core'
require_relative 'support/latch'
require_relative '../lib/bundler_api/database_url'

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

def database_url
  BundlerApi::DatabaseUrl.url(ENV['TEST_DATABASE_URL'])
end
