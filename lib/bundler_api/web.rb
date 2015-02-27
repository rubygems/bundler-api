require 'sinatra/base'
require 'sequel'
require 'json'
require 'dalli'
require 'bundler_api'
require 'bundler_api/agent_reporting'
require 'bundler_api/appsignal'
require 'bundler_api/cdn'
require 'bundler_api/dep_calc'
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

    @dalli_client =
      if ENV["MEMCACHIER_SERVERS"]
        Dalli::Client.new((ENV["MEMCACHIER_SERVERS"] || "").split(","),
                          { username: ENV["MEMCACHIER_USERNAME"],
                            password: ENV["MEMCACHIER_PASSWORD"],
                            failover: true,
                            socket_timeout: 1.5,
                            socket_failure_delay: 0.2
                          })
      else
        Dalli::Client.new
      end
    super()
  end

  set :root, File.join(File.dirname(__FILE__), '..', '..')

  not_found do
    status 404
    body JSON.dump({"error" => "Not found", "code" => 404})
  end

  def gems
    halt(200) if params[:gems].nil? || params[:gems].empty?
    params[:gems].is_a?(Array) ? params[:gems] : params[:gems].split(',')
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

      BundlerApi::Cdn.purge_specs
      delete_cache(payload.name)

      json_payload(payload)
    end
  end

  post "/api/v1/remove_spec.json" do
    Metriks.timer('webhook.remove_spec').time do
      payload    = get_payload
      rubygem_id = @write_conn[:rubygems].filter(name: payload.name.to_s).select(:id).first[:id]
      version    = @write_conn[:versions].where(
        rubygem_id: rubygem_id,
        number:     payload.version.version,
        platform:   payload.platform
      ).update(indexed: false)

      BundlerApi::Cdn.purge_specs
      BundlerApi::Cdn.purge_gem payload
      delete_cache(payload.name)

      json_payload(payload)
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
      keys.delete(key)
      dependencies += value
    end

    keys.each do |gem|
      name = gem.gsub("deps/v1/", "")
      result = BundlerApi::DepCalc.fetch_dependency(@conn, name)
      @dalli_client.set(gem, result)
      dependencies += result
    end
    dependencies
  end

  def delete_cache(gem)
    @dalli_client.delete "deps/v1/#{gem}"
  end
end
