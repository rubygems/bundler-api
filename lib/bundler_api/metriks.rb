require 'metriks'
require 'metriks/middleware'

user  = ENV['LIBRATO_METRICS_USER']
token = ENV['LIBRATO_METRICS_TOKEN']
if user && token
  require 'metriks-librato_metrics'

  prefix = ENV.fetch('LIBRATO_METRICS_PREFIX') do
    ENV['RACK_ENV'] unless ENV['RACK_ENV'] == 'production'
  end

  app_name = ENV.fetch('DYNO') do
    # Fall back to hostname if DYNO isn't set.
    require 'socket'
    Socket.gethostname
  end

  on_error = ->(e) do
    STDOUT.puts("LibratoMetrics: #{ e.message }")
    STDOUT.puts(e.backtrace)
  end

  opts     = { on_error: on_error, source: app_name }
  opts[:prefix] = prefix if prefix && !prefix.empty?

  Metriks::LibratoMetricsReporter.new(user, token, opts).start
end

