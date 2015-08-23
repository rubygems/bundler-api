require 'sinatra/base'
require 'sequel'
require 'json'
require 'bundler_api'
require 'compact_index'
require 'bundler_api/agent_reporting'
require 'bundler_api/checksum'
require 'bundler_api/gem_info'
require 'bundler_api/appsignal'
require 'bundler_api/cache'
require 'bundler_api/metriks'
require 'bundler_api/runtime_instrumentation'
require 'bundler_api/gem_helper'
require 'bundler_api/update/job'
require 'bundler_api/update/yank_job'

class BundlerApi::Web < Sinatra::Base
  API_REQUEST_LIMIT    = 200
  PG_STATEMENT_TIMEOUT = 1000
  RUBYGEMS_URL         = ENV['RUBYGEMS_URL'] || "https://www.rubygems.org"

  unless ENV['RACK_ENV'] == 'test'
    use Appsignal::Rack::Listener, name: 'bundler-api'
    use Appsignal::Rack::SinatraInstrumentation
    use Metriks::Middleware
    use BundlerApi::AgentReporting
  end

  def initialize(conn = nil, write_conn = nil)
    @rubygems_token = ENV['RUBYGEMS_TOKEN']

    statement_timeout = proc {|c| c.execute("SET statement_timeout = #{PG_STATEMENT_TIMEOUT}") }
    @conn = conn || begin
      Sequel.connect(ENV['FOLLOWER_DATABASE_URL'],
                     max_connections: ENV['MAX_THREADS'],
                     after_connect: statement_timeout)
    end

    @write_conn = write_conn || begin
      Sequel.connect(ENV['DATABASE_URL'],
                     max_connections: ENV['MAX_THREADS'])
    end

    @gem_info = BundlerApi::GemInfo.new(@conn)
    file_path = BundlerApi::GemInfo::VERSIONS_FILE_PATH
    @versions_file = CompactIndex::VersionsFile.new(file_path)

    @cache = BundlerApi::CacheInvalidator.new
    @dalli_client = @cache.memcached_client
    super()
  end

  set :root, File.join(File.dirname(__FILE__), '..', '..')

  not_found do
    status 404
    body JSON.dump({"error" => "Not found", "code" => 404})
  end

  def gems
    halt(200) if params[:gems].nil? || params[:gems].empty?
    g = params[:gems].is_a?(Array) ? params[:gems] : params[:gems].split(',')
    g.uniq
  end

  def get_deps
    timer = Metriks.timer('dependencies').time
    deps  = @gem_info.deps_for(gems)
    Metriks.histogram('gems.size').update(gems.size)
    Metriks.histogram('dependencies.size').update(deps.size)
    deps
  ensure
    timer.stop if timer
  end

  def get_payload
    params = JSON.parse(request.body.read)
    puts "webhook request: #{params.inspect}"

    if @rubygems_token && (params["rubygems_token"] != @rubygems_token)
      halt 403, "You're not Rubygems"
    end

    %w(name version platform prerelease).each do |key|
      halt 422, "No spec #{key} given" if params[key].nil?
    end

    version = Gem::Version.new(params["version"])
    BundlerApi::GemHelper.new(params["name"], version,
      params["platform"], params["prerelease"])
  rescue JSON::ParserError
    halt 422, "Invalid JSON"
  end

  def json_payload(payload)
    content_type 'application/json;charset=UTF-8'
    JSON.dump(:name => payload.name, :version => payload.version.version,
      :platform => payload.platform, :prerelease => payload.prerelease)
  end

  get "/" do
    cache_control :public, max_age: 31536000
    redirect 'https://www.rubygems.org'
  end

  get "/api/v1/dependencies" do
    halt 422, "Too many gems (use --full-index instead)" if gems.length > API_REQUEST_LIMIT

    content_type 'application/octet-stream'

    deps = with_metriks { get_cached_dependencies }
    ActiveSupport::Notifications.instrument('marshal.deps') { Marshal.dump(deps) }
  end

  get "/api/v1/dependencies.json" do
    halt 422, {
      "error" => "Too many gems (use --full-index instead)",
      "code"  => 422
    }.to_json if gems.length > API_REQUEST_LIMIT

    content_type 'application/json;charset=UTF-8'

    deps = with_metriks { get_cached_dependencies }
    ActiveSupport::Notifications.instrument('json.deps') { deps.to_json }
  end

  post "/api/v1/add_spec.json" do
    Metriks.timer('webhook.add_spec').time do
      payload = get_payload
      job = BundlerApi::Job.new(@write_conn, payload)
      job.run

      @cache.purge_specs
      @cache.purge_memory_cache(payload.name)

      json_payload(payload)
    end
  end

  post "/api/v1/remove_spec.json" do
    Metriks.timer('webhook.remove_spec').time do
      payload    = get_payload
      rubygem_id = @write_conn[:rubygems].filter(name: payload.name.to_s).select(:id).first[:id]
      @write_conn[:versions].where(
        rubygem_id: rubygem_id,
        number:     payload.version.version,
        platform:   payload.platform
      ).update(indexed: false)

      @cache.purge_specs
      @cache.purge_gem(payload.name)

      json_payload(payload)
    end
  end

  get "/names" do
    etag_response_for("names") do
     CompactIndex.names(@gem_info.names)
    end
  end

  get "/versions" do
    etag_response_for("versions") do
      from_date = @versions_file.updated_at
      extra_gems = @gem_info.versions(from_date)
      CompactIndex.versions(@versions_file, extra_gems)
    end
  end

  get "/info/:name" do
    etag_response_for(params[:name]) do
      @gem_info.info(params[:name])
    end
  end

  get "/quick/Marshal.4.8/:id" do
    redirect "#{RUBYGEMS_URL}/quick/Marshal.4.8/#{params[:id]}"
  end

  get "/fetch/actual/gem/:id" do
    redirect "#{RUBYGEMS_URL}/fetch/actual/gem/#{params[:id]}"
  end

  get "/gems/:id" do
    redirect "#{RUBYGEMS_URL}/gems/#{params[:id]}"
  end

  get "/latest_specs.4.8.gz" do
    redirect "#{RUBYGEMS_URL}/latest_specs.4.8.gz"
  end

  get "/specs.4.8.gz" do
    redirect "#{RUBYGEMS_URL}/specs.4.8.gz"
  end

  get "/prerelease_specs.4.8.gz" do
    redirect "#{RUBYGEMS_URL}/prerelease_specs.4.8.gz"
  end

private

  def etag_response_for(name)
    sum = BundlerApi::Checksum.new(@write_conn, name)

    if sum.checksum && sum.checksum == request.env["HTTP_IF_NONE_MATCH"]
      headers "ETag" => sum.checksum
      status 304
      return ""
    else
      body = yield
      sum.checksum = Digest::MD5.hexdigest(body)
      headers "ETag" => sum.checksum
      content_type 'text/plain'
      ranges = Rack::Utils.byte_ranges(env, body.bytesize)
      return body unless ranges
      status 206
      ranges.map! do |range|
        body.byteslice(range)
      end.join
    end
  end

  def deps_for(name)
    @gem_info.deps_for(Array(name))
  end

  def with_metriks
    timer = Metriks.timer('dependencies').time
    yield.tap do |deps|
      Metriks.histogram('gems.size').update(gems.size)
      Metriks.histogram('dependencies.size').update(deps.size)
    end
  ensure
    timer.stop if timer
  end

  def get_cached_dependencies
    dependencies = []
    keys = gems.map { |g| "deps/v1/#{g}" }
    @dalli_client.get_multi(keys) do |key, value|
      Metriks.meter('dependencies.memcached.hit').mark
      keys.delete(key)
      dependencies += value
    end

    keys.each do |gem|
      Metriks.meter('dependencies.memcached.miss').mark
      name = gem.gsub("deps/v1/", "")
      result = @gem_info.deps_for([name])
      @dalli_client.set(gem, result)
      dependencies += result
    end
    dependencies
  end
end
