require 'cgi'
require 'open-uri'
require 'set'
require 'bundler_api'
require 'bundler_api/dep_calc'
require 'bundler_api/gem_helper'
require 'bundler_api/metriks'
require 'bundler_api/update/job'

class BundlerApi::DepFetcher
  def initialize(memcached_client)
    @memcached_client = memcached_client
    @fetchers = []
  end

  def <<(fetcher)
    @fetchers << fetcher
  end

  def fetch(gems)
    Results.new(@memcached_client, gems) { |results|
      @fetchers.each do |fetcher|
        break if results.done?
        fetcher.fetch(results)
      end
    }.dependencies
  end

  class Results
    attr_reader :remaining_gems, :dependencies

    def initialize(memcached_client, gems)
      @memcached_client = memcached_client
      @remaining_gems = Set.new(gems)
      @dependencies = []
      yield(self)
      remaining_keys.each do |key|
        @memcached_client.set(key, [])
      end
    end

    def done?
      @remaining_gems.empty?
    end

    def remaining_keys
      @remaining_gems.map { |g| "deps/v1/#{g}" }
    end

    def found(gem, result, cache = true)
      @remaining_gems.delete gem
      @dependencies += result

      if cache
        @memcached_client.set("deps/v1/#{gem}", result)
      end
    end

    def found_key(key, result, cache = true)
      found(key.sub('deps/v1/', ''), result, false)

      if cache
        @memcached_client.set(key, result)
      end
    end
  end

  class Memcached
    def initialize(memcached_client)
      @memcached_client = memcached_client
    end

    def fetch(results)
      @memcached_client.get_multi(results.remaining_keys) do |key, value|
        Metriks.meter('dependencies.memcached.hit').mark
        results.found_key(key, value, false)
      end
    end
  end

  class Database
    def initialize(connection)
      @connection = connection
    end

    def fetch(results)
      results.remaining_gems.each do |gem|
        Metriks.meter('dependencies.memcached.miss').mark
        result = BundlerApi::DepCalc.fetch_dependency(@connection, gem)

        unless result.empty?
          results.found(gem, result)
        end
      end
    end
  end

  class GemServer
    def initialize(cache, connection, rubygems_url)
      @cache = cache
      @connection = connection
      @rubygems_url = rubygems_url
    end

    def fetch(results)
      Metriks.meter('dependencies.database.miss').mark(results.remaining_gems.size)
      dependencies = fetch_external(results.remaining_gems)
      store(dependencies)

      dependencies.group_by do |dep|
        dep[:name]
      end.each do |gem, dep|
        results.found(gem, dep)
      end
    end

    private

    def fetch_external(gems)
      puts "Fetching dependencies: #{gems.to_a.join(', ')}"
      escaped_gems = gems.map { |gem| CGI.escape(gem) }
      Marshal.load open("#{@rubygems_url}/api/v1/dependencies?gems=#{escaped_gems.join(',')}").read
    end

    # TODO: Should this do bulk inserts?
    def store(dependencies)
      payloads = get_payloads(dependencies)
      names = Set.new

      # TODO: I don't really like this transaction, but otherwise concurrent /api/v1/dependencies will be wrong
      @connection.transaction do
        payloads.each do |payload|
          BundlerApi::Job.new(@connection, payload).run
          names << payload.name
        end
      end

      @cache.purge_specs
      names.each { |name| @cache.purge_memory_cache(name) }
    end

    def get_payloads(dependencies)
      dependencies.map do |dep|
        version = Gem::Version.new(dep[:number])
        payload = BundlerApi::GemHelper.new(dep[:name], version, dep[:platform], version.prerelease?)

        spec = Gem::Specification.new do |s|
          s.name = dep[:name]
          s.version = dep[:number]
          s.platform = dep[:platform]

          dep[:dependencies].each do |d|
            d.last.split(',').each do |requirement|
              s.add_runtime_dependency(d.first, requirement.strip)
            end
          end
        end

        # TODO: Remove this temporary hack
        payload.instance_variable_set(:@gemspec, spec)
        payload
      end
    end
  end
end
