require 'rack/test'
require_relative 'spec_helper'
require_relative '../lib/bundler_api/web'

describe BundlerApi::Web do
  include Rack::Test::Methods

  class MockSequel
    @@rack_triple = [{
      name:     "rack",
      number:   "1.0.0",
      platform: "ruby",
      dep_name: nil
    }]

    def [](*args)
      case args.first
      when :rubygems, :versions
        @select = (@full ? [{:id => 1}] : [])
        @first = nil
        self
      when :dependencies
        @select = [{:id => 1}]
        @first = {:requirements => ">= 1.0"}
        self
      else
        args[2] == "1.0.1" ? [] : @@rack_triple
      end
    end

    attr_reader :whered, :filtered, :selected, :inserted, :updated
    attr_accessor :full
    def where(*args); @whered ||= []; @whered << args; self; end
    def filter(*args); @filtered ||= []; @filtered << args; self; end
    def select(*args); @selected ||= []; @selected << args; @select; end
    def insert(*args); @inserted ||= []; @inserted << args; true; end
    def update(*args); @updated ||= []; @updated << args; true; end
    def first; @first; end
    def transaction; yield; end
  end

  before do
    @read_db  = MockSequel.new
    @write_db = MockSequel.new
  end

  def app
    BundlerApi::Web.new(@read_db, @write_db)
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

      expect(@write_db.inserted[0].first[:name]).to eq("rack")
      expect(@write_db.inserted[1].first[:full_name]).to eq("rack-1.0.1")

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

    before do
      @write_db.full = true
    end

    it "removes the spec from the database" do
      post url, JSON.dump(payload)

      expect(@write_db.updated[0].first[:indexed]).to eq(false)

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
