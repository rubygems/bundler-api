$stdout.sync = true

require 'dalli'
require 'rack/cache'
require 'rack/timeout'
require './lib/bundler_api/web'

use Rack::Timeout
Rack::Timeout.timeout = 13  # seconds

use Rack::Cache, :metastore    => Dalli::Client.new,
                 :entitystore  => 'file:tmp/cache/rack/body',
                 :allow_reload => false

run BundlerApi::Web.new
