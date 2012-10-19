require 'sequel'
require 'open-uri'
require 'zlib'
require 'tmpdir'
require 'yaml'

desc "update database"
task :update do
  specs = Zlib::GzipReader.open(open('http://rubygems.org/specs.4.8.gz')) {|gz| Marshal.load(gz) } 
  Sequel.connect(ENV["DATABASE_URL"]) do |db|
    modified_specs = {}

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
        puts "Processing: #{name}-#{version.version}"

        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            full_name = "#{name}-#{version}"
            full_name << "-#{platform}" if platform != 'ruby'
            `curl https://rubygems.org/downloads/#{full_name}.gem -s -L -o - | tar vxf - 2>&1 > /dev/null`
            `gunzip metadata.gz`
            spec = YAML.load_file('metadata')


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
        end
      end

    end
  end
end
