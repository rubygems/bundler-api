module BundlerApi
  class AtomicCounter

    def initialize
      @count = 0
      @mutex = Mutex.new
    end

    def count
      @mutex.synchronize do
        @count
      end
    end

    def increment
      @mutex.synchronize do
        @count += 1
      end
    end
  end
end
