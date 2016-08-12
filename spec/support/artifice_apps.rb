require 'artifice'
require 'sinatra/base'
require 'support/gemspec_helper'

class GemspecGenerator < Sinatra::Base
  include GemspecHelper

  get "/quick/Marshal.4.8/*" do
    name, version, platform = parse_splat(params[:splat].first)
    if platform.nil?
      platform == "ruby"
    elsif platform == "jruby"
      platform == "java"
    end
    Gem.deflate(Marshal.dump(generate_gemspec(name, version, platform)))
  end

  get "/api/v2/rubygems/:name/versions/:version.json" do
    JSON.dump(name: params[:name], version: params[:version], sha: "abc123")
  end
end

class GemspecRedirect < Sinatra::Base
  include GemspecHelper

  get "/quick/Marshal.4.8/*" do
    redirect "/real/#{params[:splat].first}"
  end

  get "/real/*" do
    name, version, platform = parse_splat(params[:splat].first)
    platform ||= 'ruby'
    Gem.deflate(Marshal.dump(generate_gemspec(name, version, platform)))
  end
end

class ForeverRedirect < Sinatra::Base
  get "/quick/Marshal.4.8/*" do
    redirect "/quick/Marshal.4.8/#{params[:splat].first}"
  end
end

class GemspecHTTPError < Sinatra::Base
  include GemspecHelper

  def initialize(*)
    super
    @@run = false
  end

  get "/quick/Marshal.4.8/*" do
    if @@run
      name, version, platform = parse_splat(params[:splat].first)
      platform ||= 'ruby'
      Gem.deflate(Marshal.dump(generate_gemspec(name, version, platform)))
    else
      status 500
      @@run = true
      "OMG ERROR"
    end
  end
end

class ForeverHTTPError < Sinatra::Base
  get "/quick/Marshal.4.8/*" do
    status 500
    "OMG ERROR"
  end
end

class NonThreadSafeGenerator < Sinatra::Base
  include GemspecHelper

  def initialize(*)
    super

    @@counter = 0
    @@mutex = Mutex.new
  end

  get "/quick/Marshal.4.8/*" do
    @@counter += 1

    name, version, platform = parse_splat(params[:splat].first)
    if platform.nil?
      platform == "ruby"
    elsif platform == "jruby"
      platform == "java"
    end
    Gem.deflate(Marshal.dump(generate_gemspec(name, @@counter, platform)))
  end
end
