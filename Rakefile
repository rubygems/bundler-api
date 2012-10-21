require 'sequel'
require 'open-uri'
require 'zlib'
require 'tmpdir'
require_relative 'lib/bundler_api/update/consumer_pool'
require_relative 'lib/bundler_api/update/job'

Thread.abort_on_exception = true

def read_index(uri)
  Zlib::GzipReader.open(open(uri)) {|gz| Marshal.load(gz) }
end

desc "update database"
task :update, :thread_count do |t, args|
  thread_count  = args[:thread_count].to_i
  specs_threads = []
  specs_threads << Thread.new { read_index('http://rubygems.org/specs.4.8.gz') }
  specs_threads << Thread.new { read_index('http://rubygems.org/prerelease_specs.4.8.gz') }
  specs         = specs_threads.inject([]) {|sum, t| sum + t.value }
  puts "# of Specs: #{specs.size}"

  Sequel.connect(ENV["DATABASE_URL"], max_connections: thread_count) do |db|
    pool = ConsumerPool.new(thread_count)
    pool.start

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        specs.each do |spec|
          name, version, platform = spec
          payload = Payload.new(name, version, platform)
          job     = Job.new(db, payload)
          pool.enq(job)
        end

        puts "Finished Enqueuing Jobs!"

        pool.poison
        pool.join
      end
    end
  end
end
