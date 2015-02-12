require 'appsignal'

Appsignal.logger.info("Loading Sinatra (#{Sinatra::VERSION}) integration")

root_path   = File.expand_path(File.dirname(__FILE__))
environment = ENV['DYNO'] ? 'production' : 'development'

Appsignal.config = Appsignal::Config.new(root_path, environment)
Appsignal.start_logger($STDOUT)
Appsignal.start

if Appsignal.active?
  ::Sinatra::Application.use(Appsignal::Rack::Listener)
  ::Sinatra::Application.use(Appsignal::Rack::Instrumentation)
end
