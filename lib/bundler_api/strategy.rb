module BundlerApi
  class RedirectionStrategy
    def initialize(rubygems_url)
      @rubygems_url = rubygems_url
    end

    def get_marshal(id, app)
      app.redirect "#{@rubygems_url}/quick/Marshal.4.8/#{id}"
    end

    def get_actual_gem(id, app)
      app.redirect "#{@rubygems_url}/fetch/actual/gem/#{:id}"
    end

    def get_gem(id, app)
      app.redirect "#{@rubygems_url}/gems/#{:id}"
    end

    def get_latest_specs(app)
      app.redirect "#{@rubygems_url}/latest_specs.4.8.gz"
    end

    def get_specs(app)
      app.redirect "#{@rubygems_url}/specs.4.8.gz"
    end

    def get_prerelease_specs(app)
      app.redirect "#{@rubygems_url}/prerelease_specs.4.8.gz"
    end

  end
end
