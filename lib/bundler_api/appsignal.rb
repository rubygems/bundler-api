require 'appsignal'

Appsignal.logger.info("Loading Sinatra (#{Sinatra::VERSION}) integration")

root_path   = File.expand_path(File.dirname(__FILE__))
environment = ENV['DYNO'] ? 'production' : 'development'
config      = Appsignal::Config.new(root_path, environment, name: 'bundler-api')

Appsignal.config = config
Appsignal.start_logger($STDOUT)
Appsignal.start
