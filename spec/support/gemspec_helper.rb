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
      s.description = "#{name.capitalize} Description"
      s.email = "#{name}@example.com"
      s.homepage = "http://www.#{name}.com"
      s.require_paths = ["lib"]
      s.rubyforge_project = "#{name}"
      s.summary = "#{name.capitalize} Summary"

      s.add_runtime_dependency("bar", "~> 1.0") if name == "foo"
      s.add_development_dependency("#{name}-dev", ">= 1.0")
    end
GEMSPEC
  end


  def parse_splat(splat)
    splat.sub('.gemspec.rz', '').split('-')
  end
end
