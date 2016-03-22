require 'net/http'
require 'dalli'

module BundlerApi
  FastlyClient = Struct.new(:service_id, :base_url, :api_key) do
    def purge_key(key)
      uri = URI("https://api.fastly.com/service/#{service_id}/purge/#{key}")
      http(uri).post uri.request_uri, nil, "Fastly-Key" => api_key
    end

    def purge_path(path)
      uri = URI("#{base_url}#{path}")
      http(uri).send_request 'PURGE', uri.path, nil, "Fastly-Key" => api_key
    end

    def http(uri)
      return unless ENV['RACK_ENV'] == "production"

      Net::HTTP.new(uri.host, uri.port).tap do |http|
        http.use_ssl     = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end
    end
  end

  class CacheInvalidator

    def initialize(memcached: nil, cdn: nil)
      @memcached_client = memcached
      @cdn_client = cdn
    end

    def purge_specs
      cdn_client.purge_key  'dependencies'
      cdn_client.purge_path '/latest_specs.4.8.gz'
      cdn_client.purge_path '/specs.4.8.gz'
      cdn_client.purge_path '/prerelease_specs.4.8.gz'
      puts "Purging dependencies /latest_specs.4.8.gz /specs.4.8.gz /prerelease_specs.4.8.gz"
    end

    def purge_gem(name)
      cdn_client.purge_path "/quick/Marshal.4.8/#{name}.gemspec.rz"
      cdn_client.purge_path "/gems/#{name}.gem"
      purge_memory_cache(name)
      puts "Purging /quick/Marshal.4.8/#{name}.gemspec.rz /gems/#{name}.gem"
    end

    def purge_memory_cache(name)
      memcached_client.delete "deps/v1/#{name}"
    end

    def cdn_client
      @cdn_client ||= if ENV['FASTLY_SERVICE_ID']
        FastlyClient.new(
          ENV['FASTLY_SERVICE_ID'],
          ENV['FASTLY_BASE_URL'],
          ENV['FASTLY_API_KEY']
        )
      else
        # Create a mock Fastly client
        Class.new do
          def purge_key(key); end
          def purge_path(path); end
        end.new
      end
    end

    def memcached_client
      @memcached_client ||= if ENV["MEMCACHEDCLOUD_SERVERS"]
        servers = (ENV["MEMCACHEDCLOUD_SERVERS"] || "").split(",")
        Dalli::Client.new(
          servers, {
            username: ENV["MEMCACHEDCLOUD_USERNAME"],
            password: ENV["MEMCACHEDCLOUD_PASSWORD"],
            failover: true,
            socket_timeout: 1.5,
            socket_failure_delay: 0.2,
            expires_in: 15 * 60
          }
        )
      else
        Dalli::Client.new
      end
    end

  end
end
