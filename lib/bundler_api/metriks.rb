require 'metriks'
require 'metriks/middleware'

user  = ENV['LIBRATO_METRICS_USER']
token = ENV['LIBRATO_METRICS_TOKEN']
if user && token
  require 'metriks/reporter/librato_metrics'
  require 'socket'

  source   = Socket.gethostname
  prefix   = ENV['RACK_ENV'] || 'development'
  on_error = ->(e) do STDOUT.puts("LibratoMetrics: #{ e.message }") end
  opts = { on_error: on_error, source: source }
  opts.merge!(prefix: prefix) unless prefix == "production"
  Metriks::Reporter::LibratoMetrics.new(user, token, opts).start

  old_user  = ENV['OLD_LIBRATO_METRICS_USER']
  old_token = ENV['OLD_LIBRATO_METRICS_TOKEN']
  if old_user && old_token
    Metriks::Reporter::LibratoMetrics.new(old_user, old_token,
      on_error: on_error,
      source:   source,
    ).start
  end
else
  require 'metriks/reporter/logger'
  Metriks::Reporter::Logger.new(
    logger: Logger.new("/dev/null"),
    interval: 10
  ).start
end

