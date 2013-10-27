require 'puma/cli'
require 'puma/single'

class Puma::Single
  def backlog
    return unless @server
    @server.backlog
  end

  def running
    return unless @server
    @server.running
  end
end

class Puma::InstrumentedCLI < Puma::CLI
  attr_reader :status

  def backlog
    return unless @runner
    @runner.backlog
  end

  def running
    return unless @runner
    @runner.running
  end

  def run
    start_instrumentation
    super
  end

  private

  def start_instrumentation
    Thread.new do
      backlog_histogram = Metriks.histogram('thread_pool.backlog')
      running_histogram = Metriks.histogram('thread_pool.running')

      loop do
        sleep 1
        backlog_histogram.update(backlog)
        running_histogram.update(running)
      end
    end
  end
end
