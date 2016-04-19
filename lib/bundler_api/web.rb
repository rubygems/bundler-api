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
require 'bundler_api/strategy'

class BundlerApi::Web < Sinatra::Base
  API_REQUEST_LIMIT    = 200
  PG_STATEMENT_TIMEOUT = ENV['PG_STATEMENT_TIMEOUT'] || 1000
  RUBYGEMS_URL         = ENV['RUBYGEMS_URL'] || "https://www.rubygems.org"
  NEW_INDEX_ENABLED    = ENV['NEW_INDEX_DISABLED'].nil?

  unless ENV['RACK_ENV'] == 'test'
    use Appsignal::Rack::Listener, name: 'bundler-api'
    use Appsignal::Rack::SinatraInstrumentation
    use Metriks::Middleware
    use BundlerApi::AgentReporting
  end

  def initialize(conn = nil, write_conn = nil, gem_strategy = nil)
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
    @gem_strategy = gem_strategy || BundlerApi::RedirectionStrategy.new(RUBYGEMS_URL)
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

      Thread.new do
        @cache.purge_specs
        @cache.purge_gem(payload.name)
      end

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

      Thread.new do
        @cache.purge_specs
        @cache.purge_gem(payload.name)
      end

      json_payload(payload)
    end
  end

  get "/names" do
    status 404 unless NEW_INDEX_ENABLED
    etag_response_for("names") do
     CompactIndex.names(@gem_info.names)
    end
  end

  get "/versions" do
    status 404 unless NEW_INDEX_ENABLED
    etag_response_for("versions") do
      from_date = @versions_file.updated_at
      extra_gems = @gem_info.versions(from_date, true)
      CompactIndex.versions(@versions_file, extra_gems)
    end
  end

  get "/info/:name" do
    status 404 unless NEW_INDEX_ENABLED
    etag_response_for(params[:name]) do
      @gem_info.info(params[:name])
    end
  end

  get "/quick/Marshal.4.8/:id" do
    @gem_strategy.serve_marshal(params[:id], self)
  end

  get "/fetch/actual/gem/:id" do
    @gem_strategy.serve_actual_gem(params[:id], self)
  end

  get "/gems/:id" do
    @gem_strategy.serve_gem(params[:id], self)
  end

  get "/latest_specs.4.8.gz" do
    @gem_strategy.serve_latest_specs(self)
  end

  get "/specs.4.8.gz" do
    @gem_strategy.serve_specs(self)
  end

  get "/prerelease_specs.4.8.gz" do
    @gem_strategy.serve_prerelease_specs(self)
  end

private

  def etag_response_for(name)
    sum = BundlerApi::Checksum.new(@write_conn, name)
    return if not_modified?(sum.checksum)

    response_body = yield
    sum.checksum = Digest::MD5.hexdigest(response_body)

    headers "ETag" => quote(sum.checksum)
    headers "Surrogate-Control" => "max-age=2592000, stale-while-revalidate=60"
    content_type "text/plain"
    requested_range_for(response_body)
  end

  def not_modified?(checksum)
    etags = parse_etags(request.env["HTTP_IF_NONE_MATCH"])

    return unless etags.include?(checksum)
    headers "ETag" => quote(checksum)
    status 304
    body ""
  end

  def requested_range_for(response_body)
    ranges = Rack::Utils.byte_ranges(env, response_body.bytesize)

    if ranges
      status 206
      body ranges.map! {|range| response_body.byteslice(range) }.join
    else
      status 200
      body response_body
    end
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
      result = @gem_info.deps_for(name)
      @dalli_client.set(gem, result)
      dependencies += result
    end
    dependencies
  end

  def quote(string)
    '"' << string << '"'
  end

  def parse_etags(value)
    value ? value.split(/, ?/).select{|s| s.sub!(/"(.*)"/, '\1') } : []
  end

end
