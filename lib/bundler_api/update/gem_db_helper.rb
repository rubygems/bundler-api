require_relative '../../bundler_api'
require_relative '../metriks'

class BundlerApi::GemDBHelper
  def initialize(db, gem_cache, mutex)
    @db        = db
    @gem_cache = gem_cache
    @mutex     = mutex
  end

  def exists?(payload)
    key = payload.full_name

    if @mutex
      @mutex.synchronize do
        return @@gem_cache[key] if @gem_cache[key]
      end
    end

    timer   = Metriks.timer('job.gem_exists').time
    dataset = @db[<<-SQL, payload.name, payload.version.version, payload.platform]
    SELECT rubygems.id AS rubygem_id, versions.id AS version_id
    FROM rubygems, versions
    WHERE rubygems.id = versions.rubygem_id
      AND rubygems.name = ?
      AND versions.number = ?
      AND versions.platform = ?
      AND versions.indexed = true
    SQL

    result = dataset.first

    if @mutex
      @mutex.synchronize do
        @gem_cache[key] = result if result
      end
    end

    result
  ensure
    timer.stop if timer
  end
end
