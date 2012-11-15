require 'sequel'
require 'open-uri'
require 'zlib'
require 'tmpdir'
require 'net/http'
require 'time'
require 'locksmith/pg'
require_relative 'lib/bundler_api/update/consumer_pool'
require_relative 'lib/bundler_api/update/job'
require_relative 'lib/bundler_api/update/atomic_counter'
require_relative 'lib/bundler_api/pgstats'

$stdout.sync = true
Thread.abort_on_exception = true

begin
  require 'rspec/core/rake_task'

  desc "Run specs"
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = %w(-fs --color)
    #t.ruby_opts  = %w(-w)
  end
rescue LoadError => e
end

def read_index(uri)
  Metriks.timer('rake.read_index').time do
    Zlib::GzipReader.open(open(uri)) {|gz| Marshal.load(gz) }
  end
end

def create_hash_key(name, version, platform)
  full_name = "#{name}-#{version}"
  full_name << "-#{platform}" if platform != 'ruby'

  full_name
end

def modified?(uri, cache_file)
  timer = Metriks.timer('rake.modified').time
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
ensure
  timer.stop
end

def specs_havent_changed(specs_threads)
  !specs_threads[0].value && !specs_threads[1].value
end

def get_specs
  timer                  = Metriks.timer('rake.get_specs').time
  specs_uri              = "http://rubygems.org/specs.4.8.gz"
  prerelease_specs_uri   = "http://rubygems.org/prerelease_specs.4.8.gz"
  specs_cache            = "./tmp/specs.4.8.gz"
  prerelease_specs_cache = "./tmp/prerelease_specs.4.8.gz"
  specs_threads          = []

  FileUtils.mkdir_p("tmp")
  specs_threads << Thread.new { modified?(specs_uri, specs_cache) }
  specs_threads << Thread.new { modified?(prerelease_specs_uri, prerelease_specs_cache) }
  if specs_havent_changed(specs_threads)
    puts "HTTP 304: Specs not modified. Sleeping for 60s."
    return
  end

  specs_threads.clear

  specs_threads << Thread.new { read_index(specs_cache) }
  specs_threads << Thread.new { [:prerelease] }
  specs_threads << Thread.new { read_index(prerelease_specs_cache) }
  specs = specs_threads.inject([]) {|sum, t| sum + t.value }
  puts "# of specs from indexes: #{specs.size - 1}"

  specs
ensure
  timer.stop
end

def get_local_gems(db)
  timer = Metriks.timer('rake.get_local_gems').time
  dataset = db[<<-SQL]
    SELECT rubygems.name, versions.number, versions.platform, versions.id
    FROM rubygems, versions
    WHERE rubygems.id = versions.rubygem_id
      AND indexed = true
  SQL

  local_gems = {}
  dataset.all.each {|h| local_gems[create_hash_key(h[:name], h[:number], h[:platform])] = h[:id] }
  puts "# of non yanked local gem versions: #{local_gems.size}"

  local_gems
ensure
  timer.stop
end

def update(db, thread_count)
  specs         = get_specs
  return 60 unless specs

  timer         = Metriks.timer('rake.update').time
  add_gem_count = BundlerApi::AtomicCounter.new
  mutex         = Mutex.new
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
    key                     = create_hash_key(name, version.version, platform)
    mutex.synchronize do
      local_gems.delete(key)
    end

    # add new gems
    payload = BundlerApi::Payload.new(name, version, platform, prerelease)
    job     = BundlerApi::Job.new(db, payload, mutex, add_gem_count)
    pool.enq(job)
  end

  puts "Finished Enqueuing Jobs!"

  pool.poison
  pool.join

  local_gems.keys.each {|gem| puts "Yanking: #{gem}" }

  db[:versions].where(id: local_gems.values).update(indexed: false) unless local_gems.empty?
  puts "# of gem versions added: #{add_gem_count.count}"
  puts "# of gem versions yanked: #{local_gems.size}"
ensure
  timer.stop if timer
end

desc "update database"
task :update, :thread_count do |t, args|
  thread_count  = args[:thread_count].to_i
  Sequel.connect(ENV["DATABASE_URL"], max_connections: thread_count) do |db|
    update(db, thread_count)
  end
end

desc "continual update"
task :continual_update, :thread_count, :times do |t, args|
  count        = 0
  times        = args[:times].to_i
  thread_count = args[:thread_count].to_i

  Sequel.connect(ENV["DATABASE_URL"], max_connections: thread_count) do |db|
    Locksmith::Pg.lock("continual_update") do
      loop do
        if count < times
          sleep_time = update(db, thread_count)
          count += 1
          sleep(sleep_time) if sleep_time # be nice to the server
        else
          break
        end
      end
    end
  end
end

require 'librato/metrics'

def new_librato_client
  user  = ENV['LIBRATO_METRICS_USER']
  token = ENV['LIBRATO_METRICS_TOKEN']
  raise 'Need Librato credentials' unless user && token

  client = Librato::Metrics::Client.new
  client.authenticate user, token
  client
end

desc "collect database statistics every 60 seconds"
task :collect_db_stats do
  interval = 60  # Collect stats every 60 seconds.
  threads  = { 'pg.master'   => ENV['DATABASE_URL'],
               'pg.follower' => ENV['FOLLOWER_DATABASE_URL'] }.
    map do |label, url|
      Thread.new do
        Sequel.connect(url) do |db|
          stats = PGStats.new(db, label:    label,
                                  interval: interval,
                                  client:   new_librato_client)
          loop do
            stats.submit
            sleep(interval)
          end
        end
      end
    end

  threads.each(&:join)
end

desc "test a specific gem"
task :insert, :name, :version, :platform do |t, args|
  counter = BundlerApi::AtomicCounter.new
  mutex   = Mutex.new
  payload = BundlerApi::Payload.new(args[:name], Gem::Version.new(args[:version]), args[:platform], false)
  Sequel.connect(ENV["DATABASE_URL"], max_connections: 1) do |db|
    BundlerApi::Job.new(db, payload, mutex, counter).run
  end
end
