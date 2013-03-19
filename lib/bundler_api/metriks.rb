require 'metriks'
require 'metriks/middleware'

user  = ENV['LIBRATO_METRICS_USER']
token = ENV['LIBRATO_METRICS_TOKEN']
if user && token
  require 'metriks/reporter/librato_metrics'

  prefix = ENV.fetch('LIBRATO_METRICS_PREFIX') do
    ENV['RACK_ENV'] unless ENV['RACK_ENV'] == 'production'
  end

  app_name = ENV.fetch('PS') do
    # Fall back to hostname if PS isn't set.
    require 'socket'
    Socket.gethostname
  end

  source   = [ app_name, Process.pid ].join(':')
  on_error = ->(e) do STDOUT.puts("LibratoMetrics: #{ e.message }") end
  opts     = { on_error: on_error, source: source }
  opts[:prefix] = prefix if prefix && !prefix.empty?

  Metriks::Reporter::LibratoMetrics.new(user, token, opts).start
end

