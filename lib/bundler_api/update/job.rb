require_relative '../../bundler_api'
require_relative '../metriks'

class BundlerApi::Job
  attr_reader :payload
  @@gem_cache = {}

  def initialize(db, payload, mutex, gem_count)
    @db        = db
    @payload   = payload
    @mutex     = mutex
    @gem_count = gem_count
  end

  def run
    unless gem_exists?
      @gem_count.increment
      spec = @payload.download_spec
      puts "Adding: #{@payload.full_name}"
      @mutex.synchronize do
        insert_spec(spec)
      end
    end
  end

  private
  def gem_exists?
    key = @payload.full_name

    @mutex.synchronize do
      return true if @@gem_cache[key]
    end

    timer   = Metriks.timer('job.gem_exists').time
    dataset = @db[<<-SQL, @payload.name, @payload.version.version, @payload.platform]
    SELECT versions.id
    FROM rubygems, versions
    WHERE rubygems.id = versions.rubygem_id
      AND rubygems.name = ?
      AND versions.number = ?
      AND versions.platform = ?
    SQL

    result = dataset.count > 0

    @mutex.synchronize do
      @@gem_cache[key] = true if result
    end

    result
  ensure
    timer.stop if timer
  end

  def insert_spec(spec)
    raise "Failed to load spec" unless spec

    timer = Metriks.timer('job.insert_spec').time
    @db.transaction do
      version    = spec.version.version
      platform   = spec.platform.to_s
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
        @db[:versions].insert(
          authors:     spec.authors,
          description: spec.description,
          number:      spec.version.version,
          rubygem_id:  rubygem_id,
          updated_at:  Time.now,
          summary:     spec.summary,
          platform:    spec.platform.to_s,
          created_at:  Time.now,
          indexed:     true,
          prerelease:  @payload.prerelease,
          latest:      true,
          full_name:   spec.full_name,
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
