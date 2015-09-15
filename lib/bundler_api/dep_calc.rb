require 'bundler_api'

class BundlerApi::DepCalc
  DepKey = Struct.new(:name, :number, :platform)

  # TODO: These 2 methods may not really belong here
  # TODO: There are a lot more queries than are probably needed
  # TODO: Should this stuff be wrapped in a transaction?
  def self.store_dependencies(connection, dependencies)
    dependencies.each do |dep|
      store_dependency(connection, dep)
    end
  end

  def self.store_dependency(connection, dependency)
    gem = connection[:rubygems][name: dependency[:name]]

    if gem
      gem_id = gem[:id]
    else
      gem_id = connection[:rubygems].insert(name: dependency[:name])
    end

    version = connection[:versions][rubygem_id: gem_id, number: dependency[:number], platform: dependency[:platform], indexed: true]

    unless version
      id = connection[:versions].insert(rubygem_id: gem_id, number: dependency[:number], platform: dependency[:platform])
      version = { id: id, rubygem_id: gem_id, number: dependency[:number], platform: dependency[:platform], indexed: true }
    end

    dependency[:dependencies].each do |dep|
      dep_name = dep.first
      dep_requirements = dep.last
      dep_gem = connection[:rubygems][name: dep_name]

      if dep_gem
        dep_gem_id = dep_gem[:id]
      else
        dep_gem_id = connection[:rubygems].insert(name: dep_name)
      end

      dependency_row = connection[:dependencies].where(rubygem_id: dep_gem_id, version_id: version[:id], scope: 'runtime').first

      unless dependency_row
        connection[:dependencies].insert(rubygem_id: dep_gem_id, version_id: version[:id], requirements: dep_requirements, scope: 'runtime')
      end
    end
  end

  # @param [String] array of strings with the gem names
  def self.fetch_dependency(connection, gem)
    dataset = connection[<<-SQL, gem].all
SELECT
    rubygems.name     "name",
    versions.platform "platform",
    versions.number   "number",
    dependency_rubygems.name "dep_name",
    dependencies.requirements "requirements"
FROM
    rubygems
INNER JOIN
    versions ON rubygems.id = versions.rubygem_id AND versions.indexed IS TRUE
LEFT JOIN
    dependencies ON versions.id = dependencies.version_id AND dependencies.scope = 'runtime'
LEFT JOIN
    rubygems "dependency_rubygems" ON dependencies.rubygem_id = "dependency_rubygems".id
WHERE
    rubygems.name = ?
SQL

    ActiveSupport::Notifications.instrument('gather.deps') do
      deps = {}

      dataset.each do |row|
        key = DepKey.new(row[:name], row[:number], row[:platform])
        deps[key] ||= []
        deps[key] << [row[:dep_name], row[:requirements]] if row[:dep_name]
      end

      deps.map do |dep_key, gem_deps|
        {
          name:         dep_key.name,
          number:       dep_key.number,
          platform:     dep_key.platform,
          dependencies: gem_deps
        }
      end
    end
  end
end
