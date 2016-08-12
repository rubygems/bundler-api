require 'bundler_api'
require 'bundler_api/gem_info'
require 'bundler_api/update/gem_db_helper'

class BundlerApi::Job
  class MockMutex
    def synchronize
      yield if block_given?
    end
  end

  attr_reader :payload
  @@gem_cache = {}

  def initialize(db, payload, mutex = Mutex.new, gem_count = nil, fix_deps: false, silent: false)
    @db        = db
    @payload   = payload
    @mutex     = mutex || MockMutex.new
    @gem_count = gem_count
    @db_helper = BundlerApi::GemDBHelper.new(@db, @@gem_cache, @mutex)
    @gem_info  = BundlerApi::GemInfo.new(@db)
    @fix_deps  = fix_deps
    @silent    = silent
  end

  def run
    return if @db_helper.exists?(@payload) && !@fix_deps
    return if !@db_helper.exists?(@payload) && @fix_deps
    log "Downloading: #{@payload.full_name}\n"
    spec = @payload.download_spec
    log "Adding: #{@payload.full_name}\n"
    @mutex.synchronize do
      deps_added = insert_spec(spec)
      @gem_count.increment if @gem_count && (!deps_added.empty? || !@fix_deps)
    end
  rescue BundlerApi::HTTPError => e
    log "BundlerApi::Job#run gem=#{@payload.full_name.inspect} " +
         "message=#{e.message.inspect}"
  end

  def self.clear_cache
    @@gem_cache.clear
  end

  private

  def log(message)
    puts message unless @silent
  end

  def insert_spec(spec)
    raise "Failed to load spec" unless spec

    @db.transaction do
      rubygem_insert, rubygem_id = @db_helper.find_or_insert_rubygem(spec)
      version_insert, version_id = @db_helper.find_or_insert_version(
        spec,
        rubygem_id,
        @payload.platform,
        @fix_deps ? nil : @payload.checksum,
        true
      )
      info_checksum = Digest::MD5.hexdigest(@gem_info.info(spec.name))
      @db_helper.update_info_checksum(version_id, info_checksum)
      @db_helper.insert_dependencies(spec, version_id)
    end
  end
end
