require 'rack/test'
require_relative 'spec_helper'
require_relative '../lib/bundler_api/web'

describe BundlerApi::Web do
  include Rack::Test::Methods

  class MockSequel
    def [](*args)
      case args.first
      when :rubygems, :versions
        self
      else
        if args[2] == "1.0.1"
          []
        else
          [{
            name:     "rack",
            number:   "1.0.0",
            platform: "ruby",
            dep_name: nil
          }]
        end
      end
    end

    attr_reader :filtered, :selected, :inserted, :deleted
    def filter(*args); @filtered ||= []; @filtered << args; self; end
    def select(*args); @selected ||= []; @selected << args; self; end
    def insert(*args); @inserted ||= []; @inserted << args; true; end
    def delete(*args); @deleted ||= []; @deleted << args; true; end
    def first; nil; end
    def transaction; yield; end
  end

  before do
    @db = MockSequel.new
  end

  def app
    BundlerApi::Web.new(@db)
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

      expect(@db.inserted[0].first[:name]).to eq("rack")
      expect(@db.inserted[1].first[:full_name]).to eq("rack-1.0.1")

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

    fit "removes the spec from the database" do
      post url, JSON.dump(payload)

      expect(@db.deleted[0].first).to eq("rack-1.0.0")

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

  context "/specs.4.8.gz" do
    it "redirects" do
      get "/specs.4.8.gz"

      expect(last_response).to be_redirect
    end
  end
end
