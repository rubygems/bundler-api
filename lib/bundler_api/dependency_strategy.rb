require 'set'
require 'bundler_api/dep_calc'
require 'bundler_api/metriks'
require 'bundler_api/web_helper'

module BundlerApi::DependencyStrategy
  class Database
    def initialize(memcached_client, connection)
      @memcached_client = memcached_client
      @conn = connection
    end

    def fetch(gems)
      dependencies = []
      keys = gems.map { |g| "deps/v1/#{g}" }
      @memcached_client.get_multi(keys) do |key, value|
        Metriks.meter('dependencies.memcached.hit').mark
        keys.delete(key)
        dependencies += value
      end

      keys.each do |gem|
        Metriks.meter('dependencies.memcached.miss').mark
        name = gem.gsub('deps/v1/', '')
        result = BundlerApi::DepCalc.fetch_dependency(@conn, name)
        @memcached_client.set(gem, result)
        dependencies += result
      end
      dependencies
    end
  end

  class GemServer
    RUBYGEMS_URL = (ENV['RUBYGEMS_URL'] || "https://www.rubygems.org").freeze
    EXPIRY = 30 * 60

    def initialize(memcached_client, web_helper = nil)
      @memcached_client = memcached_client
      @web_helper = web_helper || BundlerApi::WebHelper.new
    end

    def fetch(gems)
      dependencies = []
      keys = gems.map { |g| "deps/v1/#{g}" }
      @memcached_client.get_multi(keys) do |key, value|
        Metriks.meter('dependencies.memcached.hit').mark
        keys.delete(key)
        dependencies += value
      end

      unless keys.empty?
        Metriks.meter('dependencies.memcached.miss').mark(keys.size)
        gems = keys.map { |g| g.gsub('deps/v1/', '') }
        escaped_gems = gems.map { |gem| CGI.escape(gem) }
        puts "Fetching dependencies: #{gems.join(', ')}"
        results = Marshal.load @web_helper.get("#{RUBYGEMS_URL}/api/v1/dependencies?gems=#{escaped_gems.join(',')}")
        results.group_by { |result|
          result[:name]
        }.each do |gem, result|
          @memcached_client.set("deps/v1/#{gem}", result, EXPIRY)
          dependencies += result
        end
      end

      dependencies
    end
  end
end
