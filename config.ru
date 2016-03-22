$stdout.sync = true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'bundler_api/web'
require 'rack-timeout'
require 'newrelic_rpm'

use Rack::Timeout, service_timeout: ENV.fetch('RACK_TIMEOUT', 5).to_i
use Rack::Deflater
run BundlerApi::Web.new
