class GemBuilder
  def initialize(conn)
    @conn = conn
  end

  def create_rubygem(name)
    @conn[:rubygems].insert(name: name)
  end

  def rubygem_id(name)
    @conn[:rubygems].select(:id).where(name: name)
  end

  def create_version(rubygem_id, name, version = '1.0.0', platform = 'ruby', extra_args = {})
    args = {
      indexed: true,
      time: Time.now,
      required_ruby: nil,
      rubygems_version: nil,
      checksum: nil
    }.merge(extra_args)

    full_name = "#{name}-#{version}"
    full_name << "-#{platform}" if platform != 'ruby'
    @conn[:versions].insert(
      number:     version,
      rubygem_id: rubygem_id,
      platform:   platform,
      indexed:    args[:indexed],
      prerelease: false,
      full_name:  full_name,
      created_at: args[:time],
      required_ruby_version: args[:required_ruby],
      rubygems_version: args[:rubygems_version],
      checksum: args[:checksum]
    )
  end

  def create_dependency(rubygem_id, version_id, requirements,  scope = 'runtime')
    @conn[:dependencies].insert(
      requirements: requirements,
      rubygem_id:   rubygem_id,
      version_id:   version_id,
      scope:        scope,
    )
  end
end
