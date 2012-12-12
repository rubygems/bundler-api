require 'monitor'

class Latch
  def initialize(count = 1)
    @monitor = Monitor.new
    @cv      = @monitor.new_cond
    @count   = count
  end

  def wait
    @monitor.synchronize do
      @cv.wait_until { @count > 0 }
    end
  end

  def release
    @monitor.synchronize do
      @count -= 1 if @count > 0
      @cv.broadcast if @count.zero?
    end
  end
end
