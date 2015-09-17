module BundlerApi
  RUBYGEMS_URL = (ENV['RUBYGEMS_URL'] || "https://www.rubygems.org").freeze

  class RedirectionStrategy
    def serve_marshal(id, app)
      app.redirect "#{RUBYGEMS_URL}/quick/Marshal.4.8/#{id}"
    end

    def serve_actual_gem(id, app)
      app.redirect "#{RUBYGEMS_URL}/fetch/actual/gem/#{id}"
    end

    def serve_gem(id, app)
      app.redirect "#{RUBYGEMS_URL}/gems/#{:id}"
    end

    def serve_latest_specs(app)
      app.redirect "#{RUBYGEMS_URL}/latest_specs.4.8.gz"
    end

    def serve_specs(app)
      app.redirect "#{RUBYGEMS_URL}/specs.4.8.gz"
    end

    def serve_prerelease_specs(app)
      app.redirect "#{RUBYGEMS_URL}/prerelease_specs.4.8.gz"
    end
  end

  class CachingStrategy < RedirectionStrategy
    def initialize(storage, gem_fetcher: nil)
      @storage = storage
      @gem_fetcher = GemFetcher.new || gem_fetcher
    end

    def serve_gem(id, app)
      gem = @storage.get(id)
      unless gem.exist?
        headers, content = @gem_fetcher.fetch(id)
        gem.save(headers, content)
      end
      app.headers.update(gem.headers)
      gem.content
    end
  end

  class GemFetcher
    def fetch(id)
      [{"CONTENT-TYPE" => "octet/stream"}, "zapatito"]
    end
  end
end
