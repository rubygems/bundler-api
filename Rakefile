$: << 'lib'

require 'bundler/setup'
require 'bundler_api/env'

require 'sequel'
require 'open-uri'
require 'zlib'
require 'tmpdir'
require 'net/http'
require 'time'
require 'locksmith/pg'
require 'bundler_api/cdn'
require 'bundler_api/update/consumer_pool'
require 'bundler_api/update/job'
require 'bundler_api/update/yank_job'
require 'bundler_api/update/fix_dep_job'
require 'bundler_api/update/atomic_counter'
require 'bundler_api/gem_helper'

$stdout.sync = true
Thread.abort_on_exception = true

begin
  require 'rspec/core/rake_task'

  desc "Run specs"
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = %w(-fs --color)
    #t.ruby_opts  = %w(-w)
  end
  task :default => :spec
rescue LoadError => e
  # rspec won't exist on production
end

def read_index(uri)
  Zlib::GzipReader.open(open(uri)) {|gz| Marshal.load(gz) }
end

def modified?(uri, cache_file)
  uri   = URI(uri)
  file  = nil

  file = File.stat(cache_file) if File.exists?(cache_file)

  req = Net::HTTP::Get.new(uri.request_uri)
  req['If-Modified-Since'] = file.mtime.rfc2822 if file

  res = Net::HTTP.start(uri.hostname, uri.port) {|http|
    http.request(req)
  }

  if res.response['Location']
    modified?(res.response['Location'], cache_file)
  elsif res.is_a?(Net::HTTPSuccess)
    File.open(cache_file, 'w') {|file| file.write res.body }
    true
  else
    false
  end
end

def specs_havent_changed(specs_threads)
  !specs_threads[0].value && !specs_threads[1].value
end

def get_specs
  specs_uri              = "http://rubygems.org/specs.4.8.gz"
  prerelease_specs_uri   = "http://rubygems.org/prerelease_specs.4.8.gz"
  specs_cache            = "./tmp/specs.4.8.gz"
  prerelease_specs_cache = "./tmp/prerelease_specs.4.8.gz"
  specs_threads          = []

  FileUtils.mkdir_p("tmp")
  specs_threads << Thread.new { modified?(specs_uri, specs_cache) }
  specs_threads << Thread.new { modified?(prerelease_specs_uri, prerelease_specs_cache) }
  if specs_havent_changed(specs_threads)
    print "HTTP 304: Specs not modified. Sleeping for 60s.\n"
    return
  end

  specs_threads.clear

  specs_threads << Thread.new { read_index(specs_cache) }
  specs_threads << Thread.new { [:prerelease] }
  specs_threads << Thread.new { read_index(prerelease_specs_cache) }
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
    gem_helper                       = BundlerApi::GemHelper.new(h[:name], h[:number], h[:platform])
    local_gems[gem_helper.full_name] = h[:id]
  end
  print "# of non yanked local gem versions: #{local_gems.size}\n"

  local_gems
end

def update(db, thread_count)
  specs         = get_specs
  return 60 unless specs

  add_gem_count = BundlerApi::AtomicCounter.new
  mutex         = Mutex.new
  yank_mutex    = Mutex.new
  local_gems    = get_local_gems(db)
  prerelease    = false
  pool          = BundlerApi::ConsumerPool.new(thread_count)

  pool.start
  specs.each do |spec|
    if spec == :prerelease
      prerelease = true
      next
    end

    name, version, platform = spec
    payload                 = BundlerApi::GemHelper.new(name, version, platform, prerelease)
    pool.enq(BundlerApi::YankJob.new(local_gems, payload, yank_mutex))
    pool.enq(BundlerApi::Job.new(db, payload, mutex, add_gem_count))
  end

  print "Finished Enqueuing Jobs!\n"

  pool.poison
  pool.join

  local_gems.keys.each {|gem| print "Yanking: #{gem}\n" }
  db[:versions].where(id: local_gems.values).update(indexed: false) unless local_gems.empty?
  local_gems.keys.each {|gem| BundlerApi::Cdn.purge_gem gem }

  BundlerApi::Cdn.purge_specs if !local_gems.empty? || add_gem_count.count > 0

  print "# of gem versions added: #{add_gem_count.count}\n"
  print "# of gem versions yanked: #{local_gems.size}\n"
end

def fix_deps(db, thread_count)
  specs         = get_specs
  return 60 unless specs
  counter       = BundlerApi::AtomicCounter.new
  mutex         = nil
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

def database_connection(connections = 1, &block)
  Sequel.connect(ENV['DATABASE_URL'], max_connections: connections, &block)
end

desc "update database"
task :update, :thread_count do |t, args|
  thread_count = (args[:thread_count] || 1).to_i
  database_connection(thread_count) do |db|
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
  args.with_defaults(:platform => 'ruby', :prerelease => false)
  payload = BundlerApi::GemHelper.new(args[:name], Gem::Version.new(args[:version]), args[:platform], args[:prerelease])
  database_connection do |db|
    BundlerApi::Job.new(db, payload).run
  end
end
