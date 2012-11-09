class GemBuilder
  def initialize(conn)
    @conn = conn
  end

  def create_rubygem(name)
    @conn[:rubygems].insert(
      name:       name,
      created_at: Time.now,
      updated_at: Time.now
    )
  end

  def create_version(rubygem_id, name, version = '1.0.0', platform = 'ruby', indexed = true)
    @conn[:versions].insert(
      authors:     'Christian Neukirchen',
      description: <<-EOF,
Rack provides a minimal, modular and adaptable interface for developing
web applications in Ruby.  By wrapping HTTP requests and responses in
the simplest way possible, it unifies and distills the API for web
servers, web frameworks, and software in between (the so-called
middleware) into a single method call.

Also see http://rack.rubyforge.org.
      EOF
      number:     version,
      rubygem_id: rubygem_id,
      updated_at: Time.now,
      summary:    "a modular Ruby webserver interface",
      platform:   platform,
      created_at: Time.now,
      indexed:    indexed,
      prerelease: false,
      latest:     false,
      full_name:  "#{name}-#{version}"
    )
  end

  def create_dependency(rubygem_id, version_id, requirements,  scope = 'runtime')
    @conn[:dependencies].insert(
      requirements: requirements,
      created_at:   Time.now,
      updated_at:   Time.now,
      rubygem_id:   rubygem_id,
      version_id:   version_id,
      scope:        scope,
    )
  end
end
