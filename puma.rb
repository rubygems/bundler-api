lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'bundler/setup'
require 'bundler_api/env'

threads ENV.fetch('MIN_THREADS', 0), ENV.fetch('MAX_THREADS', 1)
port ENV['PORT'] if ENV['PORT']
