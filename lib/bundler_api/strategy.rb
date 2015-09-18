require 'bundler_api/dependency_strategy'

module BundlerApi
  class RedirectionStrategy
    def initialize(rubygems_url)
      @rubygems_url = rubygems_url
    end

    def serve_marshal(id, app)
      app.redirect "#{@rubygems_url}/quick/Marshal.4.8/#{id}"
    end

    def serve_actual_gem(id, app)
      app.redirect "#{@rubygems_url}/fetch/actual/gem/#{:id}"
    end

    def serve_gem(id, app)
      app.redirect "#{@rubygems_url}/gems/#{:id}"
    end

    def serve_latest_specs(app)
      app.redirect "#{@rubygems_url}/latest_specs.4.8.gz"
    end

    def serve_specs(app)
      app.redirect "#{@rubygems_url}/specs.4.8.gz"
    end

    def serve_prerelease_specs(app)
      app.redirect "#{@rubygems_url}/prerelease_specs.4.8.gz"
    end

  end
end
