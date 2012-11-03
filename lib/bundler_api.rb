require 'sinatra/base'
require 'sequel'
require 'json'
require_relative 'bundler_api/dep_calc'
require_relative 'bundler_api/metriks'

class BundlerApi < Sinatra::Base
  RUBYGEMS_URL = "https://www.rubygems.org"

  require 'metriks/middleware'
  use Metriks::Middleware

  def initialize
    @conn = Sequel.connect(ENV["FOLLOWER_DATABASE_URL"])
  end

  get "/api/v1/dependencies" do
    return "" unless params[:gems]
    Metriks.timer('dependencies').time do
      gems = params[:gems].split(',')
      Metriks.histogram('gems.count').update(gems.size)
      deps = DepCalc.deps_for(@conn, gems)
      Metriks.histogram('dependencies.count').update(deps.size)
      Metriks.timer('dependencies.marshal').time do
        Marshal.dump(deps)
      end
    end
  end

  get "/api/v1/dependencies.json" do
    gems = params[:gems].split(',')
    DepCalc.deps_for(@conn, gems).to_json
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

  get "/prerelease_specs.4.8.gz" do
    redirect "#{RUBYGEMS_URL}/prerelease_specs.4.8.gz"
  end
end
