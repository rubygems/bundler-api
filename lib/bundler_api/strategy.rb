module BundlerApi
  class RedirectionStrategy
    def initialize(rubygems_url, server)
      @rubygems_url = rubygems_url
      @server = server
    end

    def get_marshal(id)
      redirect "/quick/Marshal.4.8/#{id}"
    end

    def get_actual_gem(id)
      redirect "/fetch/actual/gem/#{:id}"
    end

    def get_gem(id)
      redirect "/gems/#{:id}"
    end

    def get_latest_specs
      redirect "/latest_specs.4.8.gz"
    end

    def get_specs
      redirect "/specs.4.8.gz"
    end

    def get_prerelease_specs
      redirect "/prerelease_specs.4.8.gz"
    end

    private

    def redirect(path)
      @server.redirect "#{@rubygems_url}#{path}"
    end

  end
end
