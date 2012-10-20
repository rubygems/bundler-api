require 'sequel'
require 'open-uri'
require 'zlib'
require 'tmpdir'
require_relative 'lib/bundler_api/update/consumer_pool'

Thread.abort_on_exception = true
Payload = Struct.new(:name, :version, :platform)

def read_index(uri)
  Zlib::GzipReader.open(open(uri)) {|gz| Marshal.load(gz) }
end

desc "update database"
task :update, :thread_count do |t, args|
  thread_count   = args[:thread_count].to_i
  specs          = read_index('http://rubygems.org/specs.4.8.gz') + read_index('http://rubygems.org/prerelease_specs.4.8.gz')
  puts "# of Specs: #{specs.size}"
  Sequel.connect(ENV["DATABASE_URL"], max_connections: thread_count) do |db|
    pool = ConsumerPool.new(thread_count, db)
    pool.start

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        specs.each do |spec|
          name, version, platform = spec
          payload = Payload.new(name, version, platform)
          pool.enq(payload)
        end

        puts "Finished Enqueuing Jobs!"

        pool.poison
        pool.join
      end
    end
  end
end
