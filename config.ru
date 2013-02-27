$stdout.sync = true

require 'dalli'
require 'rack/cache'
require './lib/bundler_api/web'

use Rack::Cache, :metastore    => Dalli::Client.new,
                 :entitystore  => 'file:tmp/cache/rack/body',
                 :allow_reload => false

run BundlerApi::Web.new
