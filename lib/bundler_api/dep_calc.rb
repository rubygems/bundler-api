require 'bundler_api'

class BundlerApi::DepCalc
  DepKey = Struct.new(:name, :number, :platform)

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
