require 'metriks'
require 'metriks/middleware'
require 'metriks-librato_metrics'

module BundlerApi
  module Metriks
    def self.start
      return unless user && token

      prefix = ENV.fetch('LIBRATO_METRICS_PREFIX') do
        ENV['RACK_ENV'] unless ENV['RACK_ENV'] == 'production'
      end

      app_name = ENV.fetch('DYNO') do
        # Fall back to hostname if DYNO isn't set.
        require 'socket'
        Socket.gethostname
      end

      on_error = ->(e) do
        STDOUT.puts("LibratoMetrics error. The response from the server was #{e.message} #{e.res.body}")
        STDOUT.puts("The data we sent was: #{e.data.inspect}")
        STDOUT.puts(e.backtrace)
      end

      opts = { on_error: on_error, source: app_name }
      opts[:prefix] = prefix if prefix && !prefix.empty?

      ::Metriks::LibratoMetricsReporter.new(user, token, opts).start
    end

    def self.user
      ENV['LIBRATO_METRICS_USER']
    end

    def self.token
      ENV['LIBRATO_METRICS_TOKEN']
    end

  end
end

