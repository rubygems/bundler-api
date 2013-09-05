$stdout.sync = true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'bundler_api/web'
run BundlerApi::Web.new
