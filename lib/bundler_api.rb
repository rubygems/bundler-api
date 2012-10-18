require 'sinatra/base'
require_relative 'bundler_api/dep_calc'

class BundlerApi < Sinatra::Base
  RUBYGEMS_URL = "http://production.cf.rubygems.org"
  @@dep_calc = DepCalc.new('Marshal.4.8.Z')

  get "/quick/Marshal.4.8/:id" do
    redirect "#{RUBYGEMS_URL}/quick/Marshal.4.8/#{params[:id]}"
  end

  get "/fetch/actual/gem/:id" do
    redirect "#{RUBYGEMS_URL}/fetch/actual/gem/#{params[:id]}"
  end

  get "/gems/:id" do
    redirect "#{RUBYGEMS_URL}/gems/#{params[:id]}"
  end

  get "/api/v1/dependencies" do
    gems = params[:gems].split(",")
    @@dep_calc.deps_for(gems).to_s
  end

  get "/specs.4.8.gz" do
    redirect "#{RUBYGEMS_URL}/specs.4.8.gz"
  end
end
