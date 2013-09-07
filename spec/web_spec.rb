require 'rack/test'
require 'spec_helper'
require 'bundler_api/web'

describe BundlerApi::Web do
  include Rack::Test::Methods

  before do
    builder = GemBuilder.new($db)
    rack_id = builder.create_rubygem("rack")
    builder.create_version(rack_id, "rack")
  end

  def app
    BundlerApi::Web.new($db, $db)
  end

  context "GET /" do
    let(:request) { "/" }

    it "redirects to rubygems.org" do
      get request

      expect(last_response).to be_redirect
      expect(last_response.headers['Location']).
        to eq('https://www.rubygems.org')
    end
  end

  context "GET static files" do
    let(:request) { "/robots.txt" }

    it "redirects to rubygems.org" do
      get request
      expect(last_response).to be_ok
    end
  end

  context "GET nonexistent files'" do
    let(:request) { "/nonexistent" }

    it "redirects to rubygems.org" do
      get request
      expect(last_response).to be_not_found
    end
  end

  context "GET /api/v1/dependencies" do
    let(:request) { "/api/v1/dependencies" }

    context "there are no gems" do
      it "returns an empty string" do
        get request

        expect(last_response).to be_ok
        expect(last_response.body).to eq("")
      end
    end

    context "there are gems" do
      it "returns a marshal dump" do
        result = [{
          name:         'rack',
          number:       '1.0.0',
          platform:     'ruby',
          dependencies: []
        }]

        get "#{request}?gems=rack"

        expect(last_response).to be_ok
        expect(Marshal.load(last_response.body)).to eq(result)
      end
    end
  end


  context "GET /api/v1/dependencies.json" do
    let(:request) { "/api/v1/dependencies.json" }

    context "there are no gems" do
      it "returns an empty string" do
        get request

        expect(last_response).to be_ok
        expect(last_response.body).to eq("")
      end
    end

    context "there are gems" do
      it "returns a marshal dump" do
        result = [{
          "name"         => 'rack',
          "number"       => '1.0.0',
          "platform"     => 'ruby',
          "dependencies" => []
        }]

        get "#{request}?gems=rack"

        expect(last_response).to be_ok
        expect(JSON.parse(last_response.body)).to eq(result)
      end
    end
  end

  context "POST /api/v1/add_spec.json" do
    let(:url){ "/api/v1/add_spec.json" }
    let(:payload){ {:name => "rack", :version => "1.0.1",
      :platform => "ruby", :prerelease => false} }

    it "adds the spec to the database" do
      post url, JSON.dump(payload)

      expect(last_response).to be_ok
      res = JSON.parse(last_response.body)
      expect(res["name"]).to eq("rack")
      expect(res["version"]).to eq("1.0.1")
    end
  end

  context "POST /api/v1/remove_spec.json" do
    let(:url){ "/api/v1/remove_spec.json" }
    let(:payload){ {:name => "rack", :version => "1.0.0",
      :platform => "ruby", :prerelease => false} }

    it "removes the spec from the database" do
      post url, JSON.dump(payload)

      expect(last_response).to be_ok
      res = JSON.parse(last_response.body)
      expect(res["name"]).to eq("rack")
      expect(res["version"]).to eq("1.0.0")
    end
  end

  context "GET /quick/Marshal.4.8/:id" do
    it "redirects" do
      get "/quick/Marshal.4.8/rack"

      expect(last_response).to be_redirect
    end
  end

  context "GET /fetch/actual/gem/:id" do
    it "redirects" do
      get "/fetch/actual/gem/rack"

      expect(last_response).to be_redirect
    end
  end

  context "GET /gems/:id" do
    it "redirects" do
      get "/gems/rack"

      expect(last_response).to be_redirect
    end
  end

  context "/latest_specs.4.8.gz" do
    it "redirects" do
      get "/latest_specs.4.8.gz"

      expect(last_response).to be_redirect
    end
  end

  context "/specs.4.8.gz" do
    it "redirects" do
      get "/specs.4.8.gz"

      expect(last_response).to be_redirect
    end
  end

  context "/prerelease_specs.4.8.gz" do
    it "redirects" do
      get "/prerelease_specs.4.8.gz"

      expect(last_response).to be_redirect
    end
  end

  context "/api/v2/names.list" do
    before do
      any_instance_of(BundlerApi::GemInfo) do |klass|
        stub(klass).names { %w(a b c d) }
      end
    end

    it "returns an array" do
      get "/api/v2/names.list"

      expect(last_response).to be_ok
      expect(last_response.body).to eq(<<-NAMES.chomp)
a
b
c
d
      NAMES
    end
  end

  context "/api/v2/versions.list" do
    before do
      any_instance_of(BundlerApi::GemInfo) do |klass|
        stub(klass).versions {
          {
            "a" => ["1.0.0", "1.0.1"],
            "b" => ["1.0.0"],
            "c" => ["1.0.0-java"]
          }
        }
      end
    end

    it "returns versions.list" do
      get "/api/v2/versions.list"

      expect(last_response).to be_ok
      expect(last_response.body).to eq(<<-VERSIONS)
a 1.0.0,1.0.1
b 1.0.0
c 1.0.0-java
      VERSIONS
    end
  end

  context "/api/v2/deps/:gem" do
    before do
      any_instance_of(BundlerApi::GemInfo) do |klass|
        stub(klass).deps_for {
          [
            {
              name:         'rack',
              number:       '1.0.0',
              platform:     'ruby',
              dependencies: []
            },
            {
              name:         'rack',
              number:       '1.0.1',
              platform:     'ruby',
              dependencies: [['foo', '= 1.0.0'], ['bar', '>= 2.1']]
            }
          ]
        }
      end
    end

    it "should return the gem list" do
      get "/api/v2/deps/rack"

      expect(last_response).to be_ok
      expect(last_response.body).to eq(<<-DEPS)
1.0.0
1.0.1 foo:= 1.0.0,bar:>= 2.1
DEPS
    end
  end
end
