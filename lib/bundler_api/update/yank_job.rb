require_relative '../../bundler_api'
require_relative '../gem_helper'

class BundlerApi::YankJob
  def initialize(gem_cache, payload, mutex)
    @gem_cache = gem_cache
    @payload   = payload
    @mutex     = mutex
  end

  def run
    # sometimes the platform in the index is wrong,
    # so need to check the gemspec
    spec       = @payload.download_spec
    gem_helper = BundlerApi::GemHelper.new(spec.name, spec.version, spec.platform)
    @mutex.synchronize do
      @gem_cache.delete(gem_helper.full_name)
    end
  end
end
