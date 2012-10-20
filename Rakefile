require 'sequel'
require 'open-uri'
require 'zlib'
require 'tmpdir'
require_relative 'lib/bundler_api/update/consumer_pool'

Thread.abort_on_exception = true
Payload = Struct.new(:name, :version, :platform)

desc "update database"
task :update, :thread_count do |t, args|
  thread_count   = args[:thread_count].to_i
  specs          = Zlib::GzipReader.open(open('http://rubygems.org/specs.4.8.gz')) {|gz| Marshal.load(gz) }
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
