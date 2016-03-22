require 'rack/test'
require 'spec_helper'
require 'bundler_api/web'
require 'support/gem_builder'
require 'support/etag'

describe BundlerApi::Web do
  include Rack::Test::Methods

  let(:builder) { GemBuilder.new($db) }
  let(:rack_id) { builder.create_rubygem("rack") }

  before do
    builder.create_version(rack_id, "rack", "1.0.0", "ruby", info_checksum: 'racksum')
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

    it "returns disallow root" do
      get request
      expect(last_response).to be_ok
      expect(last_response.body).to eq("Disallow: /\n")
    end
  end

  context "GET nonexistent files'" do
    let(:request) { "/nonexistent" }

    it "returns a 404" do
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
        result = {
          name:         'rack',
          number:       '1.0.0',
          platform:     'ruby',
        }

        get "#{request}?gems=rack"

        expect(last_response).to be_ok
        result.each do |k,v|
          expect(Marshal.load(last_response.body).first[k]).to eq(v)
        end
      end
    end

    context "there are too many gems" do
      let(:gems) { 201.times.map { |i| "gem-#{ i }" }.join(',') }

      it "returns a 422" do
        get "#{request}?gems=#{ gems }"

        expect(last_response).not_to be_ok
        expect(last_response.status).to be 422
        expect(last_response.body).to eq("Too many gems (use --full-index instead)")
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
        result = {
          "name"             => 'rack',
          "number"           => '1.0.0',
          "platform"         => 'ruby'
        }

        get "#{request}?gems=rack"

        expect(last_response).to be_ok
        result.each do |k,v|
          expect(JSON.parse(last_response.body).first[k]).to eq(v)
        end
      end
    end

    context "there are too many gems" do
      let(:gems) { 201.times.map { |i| "gem-#{ i }" }.join(',') }

      it "returns a 422" do
        error = {
          "error" => "Too many gems (use --full-index instead)",
          "code"  => 422
        }.to_json

        get "#{request}?gems=#{ gems }"

        expect(last_response).not_to be_ok
        expect(last_response.body).to eq(error)
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
      expect(last_response.location).to end_with("/quick/Marshal.4.8/rack")
    end
  end

  context "GET /fetch/actual/gem/:id" do
    it "redirects" do
      get "/fetch/actual/gem/rack"

      expect(last_response).to be_redirect
      expect(last_response.location).to end_with("/fetch/actual/gem/rack")
    end
  end

  context "GET /gems/:id" do
    it "redirects" do
      get "/gems/rack"

      expect(last_response).to be_redirect
      expect(last_response.location).to end_with("/gems/rack")
    end
  end

  context "/latest_specs.4.8.gz" do
    it "redirects" do
      get "/latest_specs.4.8.gz"

      expect(last_response).to be_redirect
      expect(last_response.location).to end_with("/latest_specs.4.8.gz")
    end
  end

  context "/specs.4.8.gz" do
    it "redirects" do
      get "/specs.4.8.gz"

      expect(last_response).to be_redirect
      expect(last_response.location).to end_with("/specs.4.8.gz")
    end
  end

  context "/prerelease_specs.4.8.gz" do
    it "redirects" do
      get "/prerelease_specs.4.8.gz"

      expect(last_response).to be_redirect
      expect(last_response.location).to end_with("/prerelease_specs.4.8.gz")
    end
  end

  context "/names" do
    it_behaves_like "return 304 on second hit" do
      let(:url) { "/names" }
    end

    before do
      %w(a b c d).each {|gem_name| builder.create_rubygem(gem_name) }
    end

    it "returns an array" do
      get "/names"
      expect(last_response).to be_ok
      expect(last_response.body).to eq(<<-NAMES.chomp.gsub(/^        /, ''))
        ---
        a
        b
        c
        d
        rack

      NAMES
    end
  end

  context "/versions" do
    it_behaves_like "return 304 on second hit" do
      let(:url) { "/versions" }
    end

    let :versions_file do
      gem_info = BundlerApi::GemInfo.new($db)
      file_path = BundlerApi::GemInfo::VERSIONS_FILE_PATH
      CompactIndex::VersionsFile.new(file_path)
    end

    before do
      a = builder.create_rubygem("a")
      builder.create_version(a, 'a', '1.0.0', 'ruby', info_checksum: 'a100')
      builder.create_version(a, 'a', '1.0.1', 'ruby', info_checksum: 'a101')
      b = builder.create_rubygem("b")
      builder.create_version(b, 'b', '1.0.0', 'ruby', info_checksum: 'b100', indexed: false)
      c = builder.create_rubygem("c")
      builder.create_version(c, 'c', '1.0.0-java', 'ruby', info_checksum: 'c100')
      a200 = builder.create_version(a, 'a', '2.0.0', 'java', info_checksum: 'a200')
      builder.create_version(a, 'a', '2.0.1', 'ruby', info_checksum: 'a201')
      builder.yank(a200)
    end

    let(:data) do
      versions_file.contents +
        "rack 1.0.0 racksum\n" +
        "a 1.0.0 a100\n" +
        "a 1.0.1 a101\n" +
        "b 1.0.0 b100\n" +
        "c 1.0.0-java c100\n" +
        "a 2.0.0-java a200\n" +
        "a 2.0.1 a201\n" +
        "a -2.0.0-java a200\n"
    end

    let(:expected_etag) { '"' << Digest::MD5.hexdigest(data) << '"' }

    it "returns versions.list" do
      get "/versions"

      expect(last_response).to be_ok
      expect(last_response.body).to eq(data)
      expect(last_response.header["ETag"]).to eq(expected_etag)
    end
  end

  context "/info/:gem" do
    it_behaves_like "return 304 on second hit" do
      let(:url) { "/info/rack" }
    end

    context "when has no required ruby version" do
      before do
        info_test = builder.create_rubygem('info_test')
        builder.create_version(info_test, 'info_test', '1.0.0', 'ruby', checksum: 'abc123')

        info_test101= builder.create_version(info_test, 'info_test', '1.0.1', 'ruby', checksum: 'qwerty')
        [['foo', '= 1.0.0'], ['bar', '>= 2.1, < 3.0']].each do |dep, requirements|
          dep_id = builder.create_rubygem(dep)
          builder.create_dependency(dep_id, info_test101, requirements)
        end
      end

      let(:expected_deps) do
        <<-DEPS.gsub(/^          /, '')
          ---
          1.0.0 |checksum:abc123
          1.0.1 bar:< 3.0&>= 2.1,foo:= 1.0.0|checksum:qwerty
        DEPS
      end
      let(:expected_etag) { '"' << Digest::MD5.hexdigest(expected_deps) << '"' }

      it "should return the gem list" do
        get "/info/info_test"

        expect(last_response).to be_ok
        expect(last_response.body).to eq(expected_deps)
        expect(last_response.header["ETag"]).to eq(expected_etag)
      end
    end

    context "when has a required ruby version" do
      before do
        a = builder.create_rubygem("a")
        builder_args = { checksum: "abc123", required_ruby: ">1.9", rubygems_version: ">2.0" }
        a_version = builder.create_version(a, 'a', '1.0.1', 'ruby', builder_args )
        [['a_foo', '= 1.0.0'], ['a_bar', '>= 2.1, < 3.0']].each do |dep, requirements|
          dep_id = builder.create_rubygem(dep)
          builder.create_dependency(dep_id, a_version, requirements)
        end
      end

      let(:expected_deps) do
        <<-DEPS.gsub(/^          /, '')
          ---
          1.0.1 a_bar:< 3.0&>= 2.1,a_foo:= 1.0.0|checksum:abc123,ruby:>1.9,rubygems:>2.0
        DEPS
      end

      it "should return the gem list with the required ruby version" do
        get "/info/a"
        expect(last_response).to be_ok
        expect(last_response.body).to eq(expected_deps)
      end
    end
  end
end
