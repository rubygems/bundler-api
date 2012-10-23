require 'sequel'
require 'open-uri'
require 'zlib'
require 'tmpdir'
require 'net/http'
require 'time'
require_relative 'lib/bundler_api/update/consumer_pool'
require_relative 'lib/bundler_api/update/job'
require_relative 'lib/bundler_api/update/counter'

$stdout.sync = true
Thread.abort_on_exception = true

def read_index(uri)
  Zlib::GzipReader.open(open(uri)) {|gz| Marshal.load(gz) }
end

def create_hash_key(name, version, platform)
  full_name = "#{name}-#{version}"
  full_name << "-#{platform}" if platform != 'ruby'

  full_name
end

def modified?(uri, cache_file)
  uri             = URI(uri)
  file            = nil

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

def get_specs
  specs_uri              = "http://rubygems.org/specs.4.8.gz"
  prerelease_specs_uri   = "http://rubygems.org/prerelease_specs.4.8.gz"
  specs_cache            = "./tmp/specs.4.8.gz"
  prerelease_specs_cache = "./tmp/prerelease_specs.4.8.gz"
  specs_threads          = []

  FileUtils.mkdir_p("tmp")
  specs_threads << Thread.new { modified?(specs_uri, specs_cache) }
  specs_threads << Thread.new { modified?(prerelease_specs_uri, prerelease_specs_cache) }
  if !specs_threads[0].value && !specs_threads[1].value
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
end

def get_local_gems(db)
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
end

def update(db, thread_count)
  specs         = get_specs
  return 60 unless specs

  add_gem_count = Counter.new
  mutex         = Mutex.new
  local_gems    = get_local_gems(db)
  prerelease    = false
  pool          = ConsumerPool.new(thread_count)

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
    payload = Payload.new(name, version, platform, prerelease)
    job     = Job.new(db, payload, mutex, add_gem_count)
    pool.enq(job)
  end

  puts "Finished Enqueuing Jobs!"

  pool.poison
  pool.join

  local_gems.keys.each {|gem| puts "Yanking: #{gem}" }

  db[:versions].where(id: local_gems.values).update(indexed: false) unless local_gems.empty?
  puts "# of gem versions added: #{add_gem_count.count}"
  puts "# of gem versions yanked: #{local_gems.size}"
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
    loop do
      if count < times
        sleep_time = update(db, thread_count)
        count += 1
        sleep(sleep_time) if sleep_time # don't rape the server
      else
        break
      end
    end
  end
end
