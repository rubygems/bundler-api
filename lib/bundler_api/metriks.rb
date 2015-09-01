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
        begin
          STDOUT.puts("[Metriks][Librato] Error while submitting metrics: #{e.message}")
          STDOUT.puts("  #{e.res.body}")
          STDOUT.puts("  Submitted data: #{e.data.inspect}")
        rescue => e
          STDOUT.puts "#{e.class}: #{e.message}"
          STDOUT.puts e.backtrace.join("\n  ")
        end
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

