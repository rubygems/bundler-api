class GemBuilder
  def initialize(conn)
    @conn = conn
  end

  def create_rubygem(name)
    @conn[:rubygems].insert(name: name)
  end

  def create_version(rubygem_id, name, version = '1.0.0', platform = 'ruby', indexed = true)
    full_name = "#{name}-#{version}"
    full_name << "-#{platform}" if platform != 'ruby'
    @conn[:versions].insert(
      number:     version,
      rubygem_id: rubygem_id,
      platform:   platform,
      indexed:    indexed,
      prerelease: false,
      full_name:  full_name
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
