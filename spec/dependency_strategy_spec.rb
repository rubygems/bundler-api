require 'spec_helper'
require 'bundler_api/web'
require 'bundler_api/dependency_strategy'
require 'support/gem_builder'

describe BundlerApi::DependencyStrategy::Database do
  let(:memcached_client) { BundlerApi::CacheInvalidator.new.memcached_client }
  let(:strategy) { BundlerApi::DependencyStrategy::Database.new(memcached_client, $db) }

  before do
    builder = GemBuilder.new($db)

    %w(foo bar).each do |gem|
      id = builder.create_rubygem(gem)
      builder.create_version(id, gem)
    end
  end

  describe ".fetch" do
    context "one gem" do
      it "finds the gem" do
        result = [{
          name:         "foo",
          number:       "1.0.0",
          platform:     "ruby",
          dependencies: []
        }]

        expect(strategy.fetch(%w(foo))).to eq(result)
      end
    end

    context "multiple gems" do
      it "finds the gems" do
        result = [{
          name:         "foo",
          number:       "1.0.0",
          platform:     "ruby",
          dependencies: []
        }, {
          name:         "bar",
          number:       "1.0.0",
          platform:     "ruby",
          dependencies: []
        }]

        expect(strategy.fetch(%w(foo bar))).to eq(result)
      end
    end

    context "some missing gems" do
      it "finds the available gems" do
        result = [{
          name:         "foo",
          number:       "1.0.0",
          platform:     "ruby",
          dependencies: []
        }, {
          name:         "bar",
          number:       "1.0.0",
          platform:     "ruby",
          dependencies: []
        }]

        expect(strategy.fetch(%w(foo bar baz))).to eq(result)
      end
    end
  end
end

describe BundlerApi::DependencyStrategy::GemServer do
  let(:memcached_client) { BundlerApi::CacheInvalidator.new.memcached_client }
  let(:web_helper) { double }
  let(:strategy) { BundlerApi::DependencyStrategy::GemServer.new(memcached_client, web_helper) }

  def valid_url(url, expected_gems)
    expect(url).to start_with('https://www.rubygems.org/api/v1/dependencies?gems=')
    params = url.sub('https://www.rubygems.org/api/v1/dependencies?gems=', '')
    expect(params.split(',')).to match_array(expected_gems)
  end

  describe ".fetch" do
    context "one gem" do
      it "finds the gem" do
        result = [{
          name:         'foo',
          number:       '1.0.0',
          platform:     'ruby',
          dependencies: []
        }]

        expect(web_helper).to receive(:get) { |url|
          valid_url(url, %w(foo))
          Marshal.dump(result)
        }

        expect(strategy.fetch(%w(foo))).to eq(result)
      end
    end

    context "multiple gems" do
      it "finds the gems" do
        result = [{
          name:         'foo',
          number:       '1.0.0',
          platform:     'ruby',
          dependencies: []
        }, {
          name:         'bar',
          number:       '1.0.0',
          platform:     'ruby',
          dependencies: []
        }]

        expect(web_helper).to receive(:get) { |url|
          valid_url(url, %w(foo bar))
          Marshal.dump(result)
        }

        expect(strategy.fetch(%w(foo bar))).to eq(result)
      end
    end

    context "some missing gems" do
      it "finds the available gems" do
        result = [{
          name:         'foo',
          number:       '1.0.0',
          platform:     'ruby',
          dependencies: []
        }, {
          name:         'bar',
          number:       '1.0.0',
          platform:     'ruby',
          dependencies: []
        }]

        expect(web_helper).to receive(:get) { |url|
          valid_url(url, %w(foo bar baz))
          Marshal.dump(result)
        }

        expect(strategy.fetch(%w(foo bar baz))).to eq(result)
      end
    end
  end
end
