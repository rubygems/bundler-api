require 'active_support/notifications'
require 'librato/metrics'

module Rack
  module QueueMetrics
    class LibratoReporter
      def initialize(user = ENV['LIBRATO_METRICS_USER'], token = ENV['LIBRATO_METRICS_TOKEN'], prefix = ENV['LIBRATO_METRICS_PREFIX'])
        @client = Librato::Metrics::Client.new
        @prefix = prefix
        @default_options = {
          :type   => 'gauge',
          :attributes => {
            :source_aggregate => true,
            :display_min      => 0
          }
        }

        @client.authenticate(user, token)
        @queue = @client.new_queue
      end

      def setup_unicorn_queue_depth
        ActiveSupport::Notifications.subscribe("rack.queue-metrics.queue-depth") do |*args|
          _, _, _, _, payload = args
          @queue.add(instrument_name('unicorn.queue-depth') => @default_options.merge(
            :value => payload[:requests][:queued],
            :source => ENV['PS'] || payload[:addr]))
          @queue.submit
        end
      end

      private
      def instrument_name(name)
        @prefix ? "#{@prefix}.#{name}" : name
      end
    end
  end
end
