require 'sequel'
require 'open-uri'
require 'zlib'
require 'tmpdir'
require 'yaml'

Thread.abort_on_exception = true

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
    rubygem    = db[:rubygems].filter(name: spec.name).select(:id).first
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

THREAD_SIZE = 10

desc "update database"
task :update do
  specs          = Zlib::GzipReader.open(open('http://rubygems.org/specs.4.8.gz')) {|gz| Marshal.load(gz) }
  mutex          = Mutex.new
  threads        = []

  Sequel.connect(ENV["DATABASE_URL"]) do |db|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        specs.each do |spec|
          name, version, platform = spec
          dataset = db[<<-SQL, name, version.version]
            SELECT versions.id
            FROM rubygems, versions
            WHERE rubygems.id = versions.rubygem_id
              AND rubygems.name = ?
              AND versions.number = ?
SQL

          if dataset.count == 0
            threads.select {|t| !t.status }.each {|t| threads.delete(t) }

            if threads.size >= THREAD_SIZE
              thread = threads.pop
              thread.join
            end

            threads << Thread.new {
              spec = download_spec(name, version, platform)
              mutex.synchronize do
                insert_spec(db, spec)
              end
            }
          end
        end
      end
    end
  end
end
