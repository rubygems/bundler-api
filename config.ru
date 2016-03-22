$stdout.sync = true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'bundler_api/web'
require 'rack-timeout'

use Rack::Timeout, service_timeout: 5.5
use Rack::Deflater
run BundlerApi::Web.new
