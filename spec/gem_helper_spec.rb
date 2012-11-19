require_relative 'spec_helper'
require_relative '../lib/bundler_api/gem_helper'
require_relative 'support/artifice_apps'

describe BundlerApi::GemHelper do
  let(:name)    { "foo" }
  let(:version) { "1.0" }
  let(:platform) { "ruby" }
  let(:helper)  { BundlerApi::GemHelper.new(name, version, platform) }

  describe "#full_name" do
    context "when the platform is not ruby" do
      let(:platform) { "java" }

      it "prints out the platform" do
        expect(helper.full_name).to eq("foo-1.0-java")
      end
    end

    context "when the platform is ruby" do
      it "doesn't print out the platform" do
        expect(helper.full_name).to eq("foo-1.0")
      end
    end
  end

  describe "#download_spec" do
    let(:gemspec) {
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
    }

    context "when no redirect" do
      before do
        Artifice.activate_with(GemspecGenerator)
      end

      after do
        Artifice.deactivate
      end

      it "returns the gemspec" do
        expect(helper.download_spec).to eq(gemspec)
      end
    end

    context "when there's a redirect" do
      before do
        Artifice.activate_with(GemspecRedirect)
      end

      after do
        Artifice.deactivate
      end

      it "returns the gemspec" do
        expect(helper.download_spec).to eq(gemspec)
      end
    end

    context "when we keep redirecting" do
      before do
        Artifice.activate_with(ForeverRedirect)
      end

      after do
        Artifice.deactivate
      end

      it "should not go on forever" do
        expect { helper.download_spec }.to raise_error(BundlerApi::HTTPError)
      end
    end
  end
end
