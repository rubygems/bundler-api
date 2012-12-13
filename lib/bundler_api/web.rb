require 'sinatra/base'
require 'sequel'
require 'json'
require_relative '../bundler_api'
require_relative '../bundler_api/dep_calc'
require_relative '../bundler_api/metriks'
require_relative '../bundler_api/honeybadger'
require_relative '../bundler_api/gem_helper'
require_relative '../bundler_api/update/job'


class BundlerApi::Web < Sinatra::Base
  RUBYGEMS_URL = "https://www.rubygems.org"

  unless ENV['RACK_ENV'] == 'test'
    use Metriks::Middleware
    use Honeybadger::Rack
  end

  def initialize(conn = nil)
    db_url = ENV["FOLLOWER_DATABASE_URL"]
    max_conns = ENV['MAX_THREADS'] || 2
    @conn = conn || Sequel.connect(db_url, :max_connections => max_conns)
    @rubygems_token = ENV['RUBYGEMS_TOKEN']
    super()
  end

  def get_deps
    halt(200) if params[:gems].nil?

    gems, deps = nil
    Metriks.timer('dependencies').time do
      gems = params[:gems].split(',')
      deps = BundlerApi::DepCalc.deps_for(@conn, gems)
    end
    Metriks.histogram('gems.count').update(gems.size)
    Metriks.histogram('dependencies.count').update(deps.size)
    deps
  end

  error do |e|
    # Honeybadger 1.3.1 only knows how to look for rack.exception :(
    request.env['rack.exception'] = request.env['sinatra.error']
  end

  get "/api/v1/dependencies" do
    content_type 'application/octet-stream'
    Metriks.timer('dependencies.marshal').time do
      Marshal.dump(get_deps)
    end
  end

  get "/api/v1/dependencies.json" do
    content_type 'application/json;charset=UTF-8'
    Metriks.timer('dependencies.jsonify').time do
      get_deps.to_json
    end
  end

  post "/api/v1/add_spec.json" do
    params = JSON.parse(request.body.read)
    # return unless @rubygems_token && params[:rubygems_token] == @rubygems_token
    %w(name version platform prerelease).each do |key|
      halt 422, "no spec #{key} given" if params[key].nil?
    end

    version = Gem::Version.new(params["version"])
    payload = BundlerApi::GemHelper.new(params["name"], version,
      params["platform"], params["prerelease"])
    job = BundlerApi::Job.new(@conn, payload, Mutex.new)
    job.run

    content_type 'application/json;charset=UTF-8'
    JSON.dump(:name => payload.name, :version => payload.version.version,
      :platform => payload.platform, :prerelease => payload.prerelease)
  end

  post "/api/v1/remove_spec.json" do
    return unless params[:rubygems_token] == @rubygems_token

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

  get "/specs.4.8.gz" do
    redirect "#{RUBYGEMS_URL}/specs.4.8.gz"
  end

end
