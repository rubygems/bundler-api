$stdout.sync = true

require 'rack/timeout'
require './lib/bundler_api/web'

use Rack::Timeout
Rack::Timeout.timeout = 13  # seconds

run BundlerApi::Web.new
