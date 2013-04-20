require 'active_support/notifications'
require 'metriks'

module Rack
  module QueueMetrics
    class LibratoReporter
      def setup_queue_depth
        ActiveSupport::Notifications.subscribe("rack.queue-metrics.queue-depth") do |*args|
          _, _, _, _, payload = args
          begin
          Metriks.histogram(instrument_name('queue-depth')).update(payload[:requests][:queued])
          Metriks.histogram(instrument_name('active-requests')).update(payload[:requests][:active])
          rescue StandardError => e
            $stderr.puts e
          end
        end
      end

      def setup_queue_time
        ActiveSupport::Notifications.subscribe("rack.queue-metrics.queue-time") do |*args|
          _, _, _, _, payload = args
          begin
          if value = payload[:request_start_delta]
            Metriks.histogram(instrument_name('request_start_delta')).update(value)
          end
          rescue StandardError => e
            $stderr.puts e
          end
        end
      end

      def setup_app_time
        ActiveSupport::Notifications.subscribe("rack.queue-metrics.app-time") do |*args|
          _, _, _, _, payload = args
          begin
          [:app_delta, :middleware_delta].each do |key|
            if value = payload[key]
              Metriks.histogram(instrument_name(key.to_s)).update(value)
            end
          end
          rescue StandardError => e
            $stderr.puts e
          end
        end
      end

      private
      def instrument_name(name)
        @prefix ? "#{@prefix}.#{name}" : name
      end
    end
  end
end
