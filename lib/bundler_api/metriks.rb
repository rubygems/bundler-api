require 'metriks'

user  = ENV['LIBRATO_METRICS_USER']
token = ENV['LIBRATO_METRICS_TOKEN']
if user && token
  require 'metriks/reporter/librato_metrics'
  require 'socket'

  source   = Socket.gethostname
  on_error = ->(e) do STDOUT.puts("LibratoMetrics: #{ e.message }") end
  Metriks::Reporter::LibratoMetrics.new(user, token,
                                        on_error: on_error,
                                        source:   source).start

  require 'librato/metrics'
  Librato::Metrics.authenticate user, token
else
  require 'metriks/reporter/logger'
  Metriks::Reporter::Logger.new(logger:   Logger.new(STDOUT),
                                interval: 10).start
end
