require 'metriks'
require 'metriks/middleware'
require 'metriks-librato_metrics'

module BundlerApi
  class Metriks
    def self.start(worker_index = nil)
      new(ENV['LIBRATO_METRICS_USER'], ENV['LIBRATO_METRICS_TOKEN'], worker_index)
    end

    def initialize(user, token, worker_index = nil)
      return unless user && token

      opts = {
        on_error: error_handler,
        source: source_name(worker_index),
        interval: 10,
      }

      prefix = ENV.fetch('LIBRATO_METRICS_PREFIX') do
        ENV['RACK_ENV'] unless ENV['RACK_ENV'] == 'production'
      end
      opts[:prefix] = prefix if prefix && !prefix.empty?

      ::Metriks::LibratoMetricsReporter.new(user, token, opts).start
    end

  private

    def source_name(worker = nil)
      name = ENV.fetch('DYNO') do
        # Fall back to hostname if DYNO isn't set.
        require 'socket'
        Socket.gethostname
      end

      worker ? "#{name}.w#{worker}" : name
    end

    def error_handler
      -> (e) do
        STDOUT.puts("[Error][Librato] #{e.class} raised during metric submission: #{e.message}")

        if e.is_a?(::Metriks::LibratoMetricsReporter::RequestFailedError)
          STDOUT.puts("  Response body: #{e.res.body}")
          STDOUT.puts("  Submitted data: #{e.data.inspect}")
        else
          STDOUT.puts e.backtrace.join("\n  ")
        end
      end
    end
  end
end

