require_relative '../../bundler_api'
require_relative '../gem_helper'

class BundlerApi::YankJob
  def initialize(gem_cache, spec, mutex)
    @gem_cache  = gem_cache
    @spec       = spec
    @mutex      = mutex
  end

  def run
    name, version, platform = @spec
    gem_helper              = BundlerApi::GemHelper.new(name, version, platform)
    # sometimes the platform in the index is wrong,
    # so need to check the gemspec
    spec                    = gem_helper.download_spec
    gem_helper              = BundlerApi::GemHelper.new(spec.name, spec.version, spec.platform)
    @mutex.synchronize do
      @gem_cache.delete(gem_helper.full_name)
    end
  end
end
