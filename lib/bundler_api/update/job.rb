require_relative '../../bundler_api'
require_relative '../metriks'
require_relative 'gem_db_helper'

class BundlerApi::Job
  attr_reader :payload
  @@gem_cache = {}

  def initialize(db, payload, mutex, gem_count)
    @db        = db
    @payload   = payload
    @mutex     = mutex
    @gem_count = gem_count
    @db_helper = BundlerApi::GemDBHelper.new(@db, @@gem_cache, @mutex)
  end

  def run
    unless @db_helper.exists?(@payload)
      @gem_count.increment
      spec = @payload.download_spec
      puts "Adding: #{@payload.full_name}"
      @mutex.synchronize do
        insert_spec(spec)
      end
    end
  end

  def self.clear_cache
    @@gem_cache.clear
  end

  private
  def insert_spec(spec)
    raise "Failed to load spec" unless spec

    timer = Metriks.timer('job.insert_spec').time
    @db.transaction do
      version    = spec.version.version
      platform   = @payload.platform
      rubygem    = @db[:rubygems].filter(name: spec.name.to_s).select(:id).first
      rubygem_id = nil
      if rubygem
        rubygem_id = rubygem[:id]
      else
        rubygem_id = @db[:rubygems].insert(
          name:       spec.name,
          created_at: Time.now,
          updated_at: Time.now,
          downloads:  0
        )
      end

      version    = @db[:versions].filter(
        rubygem_id: rubygem_id,
        number:     version,
        platform:   platform
      ).select(:id, :indexed).first
      version_id = nil

      if version
        version_id = version[:id]
        @db[:versions].where(id: version_id).update(indexed: true) unless version[:indexed]
      else
        version_id = @db[:versions].insert(
          authors:     spec.authors,
          description: spec.description,
          number:      spec.version.version,
          rubygem_id:  rubygem_id,
          updated_at:  Time.now,
          summary:     spec.summary,
          # rubygems.org actually uses the platform from the index and not from the spec
          platform:    platform,
          created_at:  Time.now,
          indexed:     true,
          prerelease:  @payload.prerelease,
          latest:      true,
          full_name:   spec.full_name,
          # same setting as rubygems.org
          built_at:    spec.date
        )
      end

      spec.dependencies.each do |dep|
        dep_rubygem = @db[:rubygems].filter(name: dep.name).select(:id).first
        if dep_rubygem
          @db[:dependencies].insert(
            requirements: dep.requirement.to_s,
            created_at:   Time.now,
            updated_at:   Time.now,
            rubygem_id:   dep_rubygem[:id],
            version_id:   version_id,
            scope:        dep.type.to_s,
          )
        end
      end
    end
  ensure
    timer.stop if timer
  end
end
