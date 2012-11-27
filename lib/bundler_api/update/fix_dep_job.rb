require_relative '../../bundler_api'
require_relative 'gem_db_helper'

class BundlerApi::FixDepJob
  @@gem_cache = {}

  def initialize(db, payload, mutex = nil)
    @db        = db
    @payload   = payload
    @mutex     = @mutex
    @db_helper = BundlerApi::GemDBHelper.new(@db, @@gem_cache, @mutex)
  end

  def run
    if @db_helper.exists?(@payload)
      spec = @payload.download_spec
      fix_deps(spec)
    end
  end

  private
  def fix_deps(spec)
    raise "Failed to load spec" unless spec

    deps_added = []

    @db.transaction do
      _, rubygem_id = @db_helper.find_or_insert_rubygem(spec)
      _, version_id = @db_helper.find_or_insert_version(spec, rubygem_id, @payload.platform, true)
      deps_added    = @db_helper.insert_dependencies(spec, version_id)
    end

    if deps_added.any?
      deps_added.each {|dep| puts "Adding Missing Dep to #{spec.name}: #{dep}" }
    end
  end
end
