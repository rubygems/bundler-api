$stdout.sync = true

require 'rack/timeout'
require './lib/bundler_api'

use Rack::Timeout
Rack::Timeout.timeout = 28  # seconds

run BundlerApi.new
