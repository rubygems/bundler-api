require 'sinatra/base'
require 'sequel'
require 'json'
require 'bundler_api'
require 'bundler_api/dep_calc'
require 'bundler_api/metriks'
require 'bundler_api/honeybadger'
require 'bundler_api/gem_helper'
require 'bundler_api/update/job'
require 'bundler_api/update/yank_job'


class BundlerApi::Web < Sinatra::Base
  RUBYGEMS_URL = "https://www.rubygems.org"

  unless ENV['RACK_ENV'] == 'test'
    use Metriks::Middleware
    use Honeybadger::Rack
  end

  def initialize(conn = nil, write_conn = nil)
    @rubygems_token = ENV['RUBYGEMS_TOKEN']

    @conn = conn || begin
      Sequel.connect(ENV["FOLLOWER_DATABASE_URL"])
    end

    @write_conn = write_conn || begin
      Sequel.connect(ENV["DATABASE_URL"])
    end

    super()
  end

  def gems
    halt(200) if params[:gems].nil?
    params[:gems].split(',')
  end

  def get_deps
    timer = Metriks.timer('dependencies').time
    deps  = BundlerApi::DepCalc.deps_for(@conn, gems)
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

  error do |e|
    # Honeybadger 1.3.1 only knows how to look for rack.exception :(
    request.env['rack.exception'] = request.env['sinatra.error']
  end

  get "/" do
    redirect RUBYGEMS_URL
  end

  get "/api/v1/dependencies" do
    content_type 'application/octet-stream'
    deps = get_deps
    Marshal.dump(deps)
  end

  get "/api/v1/dependencies.json" do
    content_type 'application/json;charset=UTF-8'
    get_deps.to_json
  end

  post "/api/v1/add_spec.json" do
    payload = get_payload
    job = BundlerApi::Job.new(@write_conn, payload)
    job.run

    json_payload(payload)
  end

  post "/api/v1/remove_spec.json" do
    payload    = get_payload
    rubygem_id = @write_conn[:rubygems].filter(name: payload.name.to_s).select(:id).first[:id]
    version    = @write_conn[:versions].where(
      rubygem_id: rubygem_id,
      number:     payload.version.version,
      platform:   payload.platform
    ).update(indexed: false)

    json_payload(payload)
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
