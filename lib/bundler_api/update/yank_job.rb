require_relative '../../bundler_api'
require_relative '../gem_helper'

class BundlerApi::YankJob
  def initialize(gem_cache, payload, mutex = Mutex.new)
    @gem_cache = gem_cache
    @payload   = payload
    @mutex     = mutex
  end

  def run
    @mutex.synchronize do
      @gem_cache.delete(@payload.full_name)
    end
  end
end
