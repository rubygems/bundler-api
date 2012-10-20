require 'sequel'
require 'open-uri'
require 'zlib'
require 'tmpdir'
require 'yaml'
require 'thread'

Thread.abort_on_exception = true
Payload = Struct.new(:name, :version, :platform)
THREAD_SIZE = 5

def gem_exists?(db, name, version)
  dataset = db[<<-SQL, name, version.version]
    SELECT versions.id
    FROM rubygems, versions
    WHERE rubygems.id = versions.rubygem_id
      AND rubygems.name = ?
      AND versions.number = ?
SQL

  dataset.count > 0
end

def download_spec(name, version, platform)
  puts "Processing: #{name}-#{version.version}"
  full_name = "#{name}-#{version}"
  full_name << "-#{platform}" if platform != 'ruby'
  spec = nil

  Dir.mktmpdir do |dir|
    `cd #{dir} && curl https://rubygems.org/downloads/#{full_name}.gem -s -L -o - | tar vxf - 2>&1 > /dev/null`
    `cd #{dir} && gunzip metadata.gz`
    spec = YAML.load_file("#{dir}/metadata")
  end

  spec
end

def insert_spec(db, spec)
  raise "Failed to load spec" unless spec

  db.transaction do
    rubygem    = db[:rubygems].filter(name: spec.name.to_s).select(:id).first
    rubygem_id = nil
    if rubygem
      rubygem_id = rubygem[:id]
    else
      rubygem_id = db[:rubygems].insert(
        name:       spec.name,
        created_at: Time.now,
        updated_at: Time.now,
        downloads:  0
      )
    end

    version_id = db[:versions].insert(
      authors:     spec.authors,
      description: spec.description,
      number:      spec.version.version,
      rubygem_id:  rubygem_id,
      updated_at:  Time.now,
      summary:     spec.summary,
      created_at:  Time.now,
      indexed:     true,
      prerelease:  false,
      latest:      true,
      full_name:   spec.full_name,
    )
    spec.dependencies.each do |dep|
      dep_rubygem = db[:rubygems].filter(name: dep.name).select(:id).first
      if dep_rubygem
        db[:dependencies].insert(
          requirements: dep.requirement.to_s,
          created_at:   Time.now,
          updated_at:   Time.now,
          rubygem_id:   dep_rubygem[:id],
          version_id:   version_id,
          scope:        dep.type.to_s,
        )
      end
    end
  end
end

class ConsumerPool
  POISON = :poison

  def initialize(size, db)
    @size    = size
    @queue   = Queue.new
    @db      = db
    @threads = []
    @mutex   = Mutex.new
  end

  def enq(payload)
    @queue.enq(payload)
  end

  def start
    @size.times { @threads << create_thread }
  end

  def join
    @threads.each {|t| t.join }
  end

  def poison
    @size.times { @queue.enq(POISON) }
  end

  private
  def create_thread
    Thread.new {
      loop do
        payload = @queue.deq
        break if payload == POISON

        unless gem_exists?(@db, payload.name, payload.version)
          spec = download_spec(payload.name, payload.version, payload.platform)
          @mutex.synchronize do
            insert_spec(@db, spec)
          end
        end
      end
    }
  end
end

desc "update database"
task :update do
  specs          = Zlib::GzipReader.open(open('http://rubygems.org/specs.4.8.gz')) {|gz| Marshal.load(gz) }
  Sequel.connect(ENV["DATABASE_URL"], max_connections: THREAD_SIZE) do |db|
    pool = ConsumerPool.new(THREAD_SIZE, db)
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
