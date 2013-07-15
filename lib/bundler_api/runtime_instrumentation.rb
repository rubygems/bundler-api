require 'hitimes'

class BundlerApi::RuntimeInstrumentation
  attr_accessor :interval, :ruby_thread

  def initialize(options = {})
    @interval = (options[:interval] || 1.0).to_f
  end

  def self.start
    new.start
  end

  def start
    return if ruby_thread && ruby_thread.alive?

    self.ruby_thread = Thread.new do
      histogram = Metriks.histogram('ruby.variance')

      while true
        ruby_interval = Hitimes::Interval.now
        sleep interval
        histogram.update(ruby_interval.duration - interval)
      end
    end
  end
end

BundlerApi::RuntimeInstrumentation.start
