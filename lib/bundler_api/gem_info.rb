require 'bundler_api'
require 'compact_index'

# Return data about all the gems: all gem names, all versions of all gems, all dependencies for all versions of a gem
class BundlerApi::GemInfo
  VERSIONS_FILE_PATH = "./versions.list"
  DepKey = Struct.new(:name, :number, :platform, :required_ruby_version, :rubygems_version, :checksum, :created_at)

  def initialize(connection)
    @conn = connection
  end

  # @param [String] array of strings with the gem names
  def deps_for(gems = [])
    dataset =
      if gems.any?
        @conn[<<-SQL, Sequel.value_list(gems)]
          SELECT rv.name, rv.number, rv.platform, rv.required_ruby_version, rv.checksum,
                 rv.rubygems_version, d.requirements, rv.created_at, for_dep_name.name dep_name
          FROM
            (SELECT r.name, v.number, v.platform,v.rubygems_version, v.checksum,
                    v.required_ruby_version, v.created_at, v.id AS version_id
            FROM rubygems AS r, versions AS v
            WHERE v.rubygem_id = r.id
              AND v.indexed is true
              AND r.name IN ?
              ORDER BY v.created_at, v.number, v.platform) AS rv
          LEFT JOIN dependencies AS d ON
            d.version_id = rv.version_id
          LEFT JOIN rubygems AS for_dep_name ON
            d.rubygem_id = for_dep_name.id
            AND d.scope = 'runtime'
          ORDER BY rv.created_at, rv.number, rv.platform, for_dep_name.name;
        SQL
      else
        @conn[<<-SQL]
          SELECT rv.name, rv.number, rv.platform, d.requirements, for_dep_name.name dep_name
          FROM
            (SELECT r.name, v.number, v.platform, v.id AS version_id
            FROM rubygems AS r, versions AS v
            WHERE v.rubygem_id = r.id
              AND v.indexed is true) AS rv
          LEFT JOIN dependencies AS d ON
            d.version_id = rv.version_id
          LEFT JOIN rubygems AS for_dep_name ON
            d.rubygem_id = for_dep_name.id
            AND d.scope = 'runtime';
        SQL
      end

    deps = {}

    dataset.each do |row|
      key = DepKey.new(
        row[:name],
        row[:number],
        row[:platform],
        row[:required_ruby_version],
        row[:rubygems_version],
        row[:checksum],
        row[:created_at]
      )
      deps[key] = [] unless deps[key]
      deps[key] << [row[:dep_name], row[:requirements]] if row[:dep_name]
    end

    deps.map do |dep_key, gem_deps|
      {
        name:                  dep_key.name,
        number:                dep_key.number,
        platform:              dep_key.platform,
        rubygems_version:      dep_key.rubygems_version,
        ruby_version:          dep_key.required_ruby_version,
        checksum:              dep_key.checksum,
        created_at:            dep_key.created_at,
        dependencies:          gem_deps
      }
    end
  end

  # return list of gem names
  def names
    @conn[:rubygems].select(:name).order(:name).all.map {|r| r[:name] }
  end

  def versions(date,include_yanks = false)
    if include_yanks
      dataset = @conn[<<-SQL, date,date]
            (SELECT r.name, v.created_at as date, v.info_checksum, v.number, v.platform
            FROM rubygems AS r, versions AS v
            WHERE v.rubygem_id = r.id AND
                  v.created_at > ?)
            UNION
            (SELECT r.name, v.yanked_at as date, v.info_checksum, '-'||v.number, v.platform
            FROM rubygems AS r, versions AS v
            WHERE v.rubygem_id = r.id AND
                  v.indexed is false AND
                  v.yanked_at > ?)
            ORDER BY date, number, platform, name
      SQL
    else
      dataset = @conn[<<-SQL, date]
            SELECT r.name, v.created_at, v.checksum, v.info_checksum, v.number, v.platform
            FROM rubygems AS r, versions AS v
            WHERE v.rubygem_id = r.id AND
                  v.indexed is true AND
                  v.created_at > ?
            ORDER BY v.created_at, v.number, v.platform, r.name
      SQL
    end
    dataset.map do |entry|
      CompactIndex::Gem.new(entry[:name], [
        CompactIndex::GemVersion.new(
          entry[:number],
          entry[:platform],
          entry[:checksum],
          entry[:info_checksum]
        )
      ])
    end
  end

  def info(name)
    deps = deps_for([name])
    deps.map! do |dep|
      dependencies = dep[:dependencies].map do |d|
        CompactIndex::Dependency.new(d[0], d[1])
      end

      CompactIndex::GemVersion.new(
        dep[:number],
        dep[:platform],
        dep[:checksum],
        dep[:info_checksum],
        dependencies,
        dep[:ruby_version],
        dep[:rubygems_version]
      )
    end
    CompactIndex.info(deps)
  end
end
