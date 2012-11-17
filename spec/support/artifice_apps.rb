require 'sinatra/base'

module GemspecHelper
  private
  def generate_gemspec(name, version, platform = 'ruby')
eval(<<GEMSPEC)
    Gem::Specification.new do |s|
      s.name = "#{name}"
      s.version = "#{version}"
      s.platform = "#{platform}"

      s.authors = ["Terence Lee"]
      s.date = "2010-10-24"
      s.description = "Foo"
      s.email = "foo@example.com"
      s.homepage = "http://www.foo.com"
      s.require_paths = ["lib"]
      s.rubyforge_project = "foo"
      s.summary = "Foo"
    end
GEMSPEC
  end

  def parse_splat(splat)
    splat.sub('.gemspec.rz', '').split('-')
  end
end

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
