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

      def setup_queue_depth
        ActiveSupport::Notifications.subscribe("rack.queue-metrics.queue-depth") do |*args|
          _, _, _, _, payload = args
          @queue.add(instrument_name('queue-depth') => @default_options.merge(
            :value => payload[:requests][:queued],
            :source => ENV['PS'] || payload[:addr]))
          @queue.add(instrument_name('active-requests') => @default_options.merge(
            :value => payload[:requests][:active],
            :source => ENV['PS'] || payload[:addr]))
          @queue.submit
        end
      end

      def setup_queue_time
        ActiveSupport::Notifications.subscribe("rack.queue-metrics.queue-time") do |*args|
          begin
          _, _, _, _, payload = args
          if value = payload[:request_start_delta]
            @queue.add(instrument_name('request_start_delta') => @default_options.merge(:value => value))
            @queue.submit
          end
          rescue Exception => e
            $stderr.puts e
          end
        end
      end

      def setup_app_time
        ActiveSupport::Notifications.subscribe("rack.queue-metrics.app-time") do |*args|
          begin
            _, _, _, _, payload = args
            [:app_delta, :middleware_delta].each do |key|
              if value = payload[key]
                @queue.add(instrument_name(key.to_s) => @default_options.merge(:value => value))
                @queue.submit
              end
            end
          rescue Exception => e
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
