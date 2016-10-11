$: << 'lib'

require 'bundler/setup'
require 'bundler_api/env'

require 'sequel'
require 'open-uri'
require 'zlib'
require 'tmpdir'
require 'net/http'
require 'time'
require 'compact_index'

require 'bundler_api/cache'
require 'bundler_api/update/consumer_pool'
require 'bundler_api/update/job'
require 'bundler_api/update/yank_job'
require 'bundler_api/update/fix_dep_job'
require 'bundler_api/update/atomic_counter'
require 'bundler_api/gem_helper'
require 'bundler_api/gem_info'

$stdout.sync = true
Thread.abort_on_exception = true

begin
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'

  RuboCop::RakeTask.new

  desc "Run specs"
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = %w(--color)
  end
  task :spec => :rubocop
  task :default => :spec
rescue LoadError => e
  # rspec won't exist on production
end

def download_index(url)
  uri = URI(url)

  Tempfile.create(uri.path) do |file|
    file.write(open(uri.to_s).read)
    file.rewind

    Zlib::GzipReader.open(file) do |gz|
      Marshal.load(gz)
    end
  end
end

def get_specs
  rubygems_host          = ENV.fetch("RUBYGEMS_URL", "https://rubygems.org")
  specs_uri              = File.join(rubygems_host, "specs.4.8.gz")
  prerelease_specs_uri   = File.join(rubygems_host, "prerelease_specs.4.8.gz")
  specs_threads          = []

  specs_threads << Thread.new { download_index(specs_uri) }
  specs_threads << Thread.new { [:prerelease] }
  specs_threads << Thread.new { download_index(prerelease_specs_uri) }
  specs = specs_threads.inject([]) {|sum, t| sum + t.value }
  print "# of specs from indexes: #{specs.size - 1}\n"

  specs
end

def get_local_gems(db)
  dataset = db[<<-SQL]
    SELECT rubygems.name, versions.number, versions.platform, versions.id
    FROM rubygems, versions
    WHERE rubygems.id = versions.rubygem_id
      AND indexed = true
  SQL

  local_gems = {}
  dataset.all.each do |h|
    gem_helper = BundlerApi::GemHelper.new(h[:name], h[:number], h[:platform])
    local_gems[gem_helper.full_name] = h[:id]
  end
  print "# of non yanked local gem versions: #{local_gems.size}\n"

  local_gems
end

def update(db, thread_count)
  specs = get_specs
  return 60 unless specs

  add_gem_count = BundlerApi::AtomicCounter.new
  mutex         = Mutex.new
  yank_mutex    = Mutex.new
  local_gems    = get_local_gems(db)
  prerelease    = false
  pool          = BundlerApi::ConsumerPool.new(thread_count)
  cache         = BundlerApi::CacheInvalidator.new

  if (specs.size - 1) == local_gems.size
    puts "Gem counts match, seems like we're already up to date!"
    return
  end

  pool.start
  specs.each do |spec|
    if spec == :prerelease
      prerelease = true
      next
    end

    name, version, platform = spec
    payload = BundlerApi::GemHelper.new(name, version, platform, prerelease)
    pool.enq(BundlerApi::YankJob.new(local_gems, payload, yank_mutex))
    pool.enq(BundlerApi::Job.new(db, payload, mutex, add_gem_count, cache: cache))
  end

  print "Finished Enqueuing Jobs!\n"

  pool.poison
  pool.join

  cache = BundlerApi::CacheInvalidator.new

  unless local_gems.empty?
    print "Yanking #{local_gems.size} gems\n"
    local_gems.keys.each {|name| print "Yanking: #{name}\n" }

    db[:versions]
      .where(:id => local_gems.values)
      .update(indexed: false, yanked_at: Time.now)

    versions = db[:versions]
      .join(:rubygems, id: :rubygem_id)
      .where(versions__id: local_gems.values)
    versions.each do |version|
      gem_helper = BundlerApi::GemHelper.new(version[:name], version[:number], version[:platform])
      cache.purge_gem(gem_helper)
    end
  end

  cache.purge_specs if !local_gems.empty? || add_gem_count.count > 0

  print "# of gem versions added: #{add_gem_count.count}\n"
  print "# of gem versions yanked: #{local_gems.size}\n"
end

def fix_deps(db, thread_count)
  specs = get_specs
  return 60 unless specs
  counter       = BundlerApi::AtomicCounter.new
  mutex         = Mutex.new
  prerelease    = false
  pool          = BundlerApi::ConsumerPool.new(thread_count)

  pool.start

  prerelease    = false
  specs.each do |spec|
    if spec == :prerelease
      prerelease = true
      next
    end

    name, version, platform = spec
    payload = BundlerApi::GemHelper.new(name, version, platform, prerelease)
    pool.enq(BundlerApi::FixDepJob.new(db, payload, counter, mutex))
  end

  print "Finished Enqueuing Jobs!\n"

  pool.poison
  pool.join

  print "# of gem deps fixed: #{counter.count}\n"
end

def database_connection(limit = 1)
  limit = [limit, 50].min
  print "Connecting to database with up to #{limit} connections... "
  Sequel.connect(ENV['DATABASE_URL'], max_connections: limit) do |db|
    print "connected!\n"
    yield db
  end
end

desc "update database"
task :update, :thread_count do |t, args|
  thread_count = (args[:thread_count] || 1).to_i
  database_connection(thread_count) do |db|
    db["select count(*) from rubygems"].count
    update(db, thread_count)
  end
end

desc "fixing existing dependencies"
task :fix_deps, :thread_count do |t, args|
  thread_count = (args[:thread_count] || 1).to_i
  database_connection(thread_count) do |db|
    fix_deps(db, thread_count)
  end
end

desc "Add a specific single gem version to the database"
task :add_spec, :name, :version, :platform, :prerelease do |t, args|
  cache = BundlerApi::CacheInvalidator.new
  args.with_defaults(:platform => 'ruby', :prerelease => false)
  payload = BundlerApi::GemHelper.new(args[:name], Gem::Version.new(args[:version]), args[:platform], args[:prerelease])
  database_connection do |db|
    BundlerApi::Job.new(db, payload, cache: cache).run
  end
end

desc "Generate/update the versions.list file"
task :versions do |t, args|
  database_connection do |db|
    file_path = BundlerApi::GemInfo::VERSIONS_FILE_PATH
    versions_file = CompactIndex::VersionsFile.new(file_path)
    gem_info = BundlerApi::GemInfo.new(db)

    last_update = versions_file.updated_at
    gems = gem_info.versions(last_update)
    versions_file.update_with(gems)
  end
end

desc "Yank a specific single gem from the database"
task :yank_spec, :name, :version, :platform do |t, args|
  args.with_defaults(:platform => 'ruby')
  database_connection do |db|
    gem_id = db[:rubygems].where(name: args[:name]).first[:id]
    version = db[:versions].where(
      rubygem_id: gem_id,
      number: args[:version],
      platform: args[:platform]
    ).first
    version.update(indexed: false, yanked_at: Time.now)

    puts "Yanked #{version}!"
  end
end

desc "Purge new index from Fastly cache"
task :purge_cdn do
  cdn = BundlerApi::CacheInvalidator.new.cdn_client
  cdn.purge_path("/names")
  cdn.purge_path("/versions")
  cdn.purge_key("info/*")
end
