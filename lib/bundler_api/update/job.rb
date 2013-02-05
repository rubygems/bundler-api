require_relative '../../bundler_api'
require_relative '../metriks'
require_relative 'gem_db_helper'

class BundlerApi::Job
  attr_reader :payload
  @@gem_cache = {}

  def initialize(db, payload, mutex = Mutex.new, gem_count = nil)
    @db        = db
    @payload   = payload
    @mutex     = mutex
    @gem_count = gem_count
    @db_helper = BundlerApi::GemDBHelper.new(@db, @@gem_cache, @mutex)
  end

  def run
    unless @db_helper.exists?(@payload)
      @gem_count.increment if @gem_count
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
      rubygem_insert, rubygem_id = @db_helper.find_or_insert_rubygem(spec)
      version_insert, version_id = @db_helper.find_or_insert_version(spec, rubygem_id, @payload.platform, true)
      @db_helper.insert_dependencies(spec, version_id)
    end
  ensure
    timer.stop if timer
  end
end
