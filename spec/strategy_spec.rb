require 'rack/test'
require 'spec_helper'
require 'bundler_api/web'
require 'bundler_api/strategy'
require 'bundler_api/storage'

describe BundlerApi::CachingStrategy do
  include Rack::Test::Methods

  before do
    @gem_folder = Dir.mktmpdir
  end

  after do
    FileUtils.remove_entry @gem_folder
  end

  let(:storage) { BundlerApi::GemStorage.new(@gem_folder) }

  let(:app) {
    BundlerApi::Web.new(
      conn         = $db,
      write_con    = $db,
      gem_strategy = BundlerApi::CachingStrategy.new(storage))
  }

  it "fetchs the gem file, stores, and serves it" do
    get "/gems/rack"
    expect(last_response.body).to eq('zapatito')
    expect(last_response.header["CONTENT-TYPE"]).to eq('octet/stream')
    expect(storage.get("rack")).to exist
  end

end
