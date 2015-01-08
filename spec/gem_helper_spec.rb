require 'spec_helper'
require 'support/artifice_apps'
require 'bundler_api/gem_helper'

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
        expect { helper.download_spec }.to raise_error()
      end
    end

    context "when there's a http error" do
      before do
        Artifice.activate_with(GemspecHTTPError)
      end

      after do
        Artifice.deactivate
      end

      it "retries in case it's a hiccup" do
        expect(helper.download_spec).to eq(gemspec)
      end
    end

    context "when it's always throwing an error" do
      before do
        stub_const("BundlerApi::GemHelper::TRY_LIMIT", 1)
        Artifice.activate_with(ForeverHTTPError)
      end

      after do
        Artifice.deactivate
      end

      it "raises an error" do
        expect { helper.download_spec }.to raise_error()
      end
    end

    context "when using multiple threads" do
      let(:version) { "1" }
      let(:port)    { 2000 }

      Thread.abort_on_exception = true

      before do
        @rackup_thread = Thread.new {
          server = Rack::Server.new(:app       => NonThreadSafeGenerator,
                                    :Host      => '0.0.0.0',
                                    :Port      => port,
                                    :server    => 'webrick',
                                    :AccessLog => [])
          server.start
        }
        @rackup_thread.run

        # ensure server is started
        require 'timeout'
        Timeout.timeout(15) { sleep(0.1) until @rackup_thread.status == "sleep" }
        sleep(1)
      end

      after do
        @rackup_thread.kill
      end

      it "is threadsafe" do
        5.times.map do
          Thread.new { helper.download_spec("http://localhost:#{port}") }
        end.each do |t|
          expect(t.value).to eq(gemspec)
        end
      end
    end
  end
end
