require 'rack/test'
require_relative 'spec_helper'
require_relative '../lib/bundler_api/web'

describe BundlerApi::Web do
  include Rack::Test::Methods

  MockSequel = Class.new(Object) do
    define_method(:[]) do |conn, gems|
      [{
        name:     "rack",
        number:   "1.0.0",
        platform: "ruby",
        dep_name: nil
      }]
    end
  end

  def app
    BundlerApi::Web.new(MockSequel.new)
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
end
