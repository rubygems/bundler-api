require_relative 'spec_helper'
require_relative '../lib/bundler_api/database_url'

describe BundlerApi::DatabaseUrl do
  describe ".url" do
    let(:username) { "username" }
    let(:password) { "password" }
    let(:host)     { "host" }
    let(:dbname)   { "dbname" }
    let(:port)     { "5432" }
    let(:url) { "postgres://#{username}:#{password}@#{host}:#{port}/#{dbname}" }

    it "should print out a proper jdbc url", :if => RUBY_ENGINE == 'jruby' do
      result = "jdbc:postgresql://#{host}:#{port}/#{dbname}?user=#{username}&password=#{password}"

      expect(BundlerApi::DatabaseUrl.url(url)).to eq(result)
    end

    it "should print out the same url", :unless => RUBY_ENGINE == 'jruby' do
      expect(BundlerApi::DatabaseUrl.url(url)).to eq(url)
    end
  end
end
