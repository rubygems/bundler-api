class GemspecGenerator < Sinatra::Base
  get "/quick/Marshal.4.8/*" do
    name, version, platform = params[:splat].first.sub('.gemspec.rz', '').split('-')
    platform ||= 'ruby'
    Gem.deflate(Marshal.dump(generate_gemspec(name, version, platform)))
  end

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
end

class GemspecJrubyGenerator < Sinatra::Base
  get "/quick/Marshal.4.8/*" do
    name, version, platform = params[:splat].first.sub('.gemspec.rz', '').split('-')
    platform = 'java'
    Gem.deflate(Marshal.dump(generate_gemspec(name, version, platform)))
  end

  private
  def generate_gemspec(name, version, platform = 'ruby')
eval(<<-GEMSPEC)
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
end

class GemspecRedirect < Sinatra::Base
end
