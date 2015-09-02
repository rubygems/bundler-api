require 'metriks'
require 'metriks/middleware'
require 'metriks-librato_metrics'

module BundlerApi
  module Metriks
    def self.start(worker_index = nil)
      return unless user && token

      prefix = ENV.fetch('LIBRATO_METRICS_PREFIX') do
        ENV['RACK_ENV'] unless ENV['RACK_ENV'] == 'production'
      end

      source_name = ENV.fetch('DYNO') do
        # Fall back to hostname if DYNO isn't set.
        require 'socket'
        Socket.gethostname
      end
      source_name += ".w#{worker_index}" if worker_index

      on_error = -> (e) do
        STDOUT.puts("[Metriks][Librato] #{e.class} raised during metric submission: #{e.message}")

        if e.is_a?(::Metriks::LibratoMetricsReporter::RequestFailedError)
          STDOUT.puts("  Response body: #{e.res.body}")
          STDOUT.puts("  Submitted data: #{e.data.inspect}")
        else
          STDOUT.puts e.backtrace.join("\n  ")
        end
      end

      opts = { on_error: on_error, source: source_name }
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

