require 'sinatra/base'
require 'sequel'
require 'json'
require_relative 'bundler_api/dep_calc'

class BundlerApi < Sinatra::Base
  DB           = Sequel.connect(ENV["DATABASE_URL"])
  RUBYGEMS_URL = "http://production.cf.rubygems.org"

  get "/api/v1/dependencies" do
    gems = params[:gems].split(',')
    Marshal.dump(DepCalc.deps_for(DB, gems))
  end

  get "/api/v1/dependencies.json" do
    gems = params[:gems].split(',')
    DepCalc.deps_for(DB, gems).to_json
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
