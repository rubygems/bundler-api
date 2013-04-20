require 'active_support/notifications'
require 'metriks'

module Rack
  module QueueMetrics
    class MetriksReporter
      def initialize(registry = Metriks)
        @registry = registry
      end

      def setup_all
        setup_queue_depth
        setup_queue_time
        setup_app_time
      end

      def setup_queue_depth
        ActiveSupport::Notifications.subscribe("rack.queue-metrics.queue-depth") do |*args|
          _, _, _, _, payload = args
          @registry.histogram('queue-depth').update(payload[:requests][:queued])
          @registry.histogram('active-requests').update(payload[:requests][:active])
        end
      end

      def setup_queue_time
        ActiveSupport::Notifications.subscribe("rack.queue-metrics.queue-time") do |*args|
          _, _, _, _, payload = args
          if value = payload[:request_start_delta]
            @registry.histogram('request_start_delta').update(value)
          end
        end
      end

      def setup_app_time
        ActiveSupport::Notifications.subscribe("rack.queue-metrics.app-time") do |*args|
          _, _, _, _, payload = args
          [:app_delta, :middleware_delta].each do |key|
            if value = payload[key]
              @registry.histogram(key.to_s).update(value)
            end
          end
        end
      end
    end
  end
end
