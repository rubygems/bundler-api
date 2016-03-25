require 'spec_helper'
require 'bundler_api/cache'

describe BundlerApi::CacheInvalidator do
  let(:client) { double(:client, purge_path: nil, purge_key: nil) }
  let(:cache) { BundlerApi::CacheInvalidator.new(cdn: client) }

  describe '.purge_specs' do
    subject { cache.purge_specs }

    it 'purges dependencies key' do
      expect(client).to receive(:purge_key).with('dependencies')
      subject
    end

    it 'purges latest specs' do
      expect(client).to receive(:purge_path).with('/latest_specs.4.8.gz')
      subject
    end

    it 'purges specs' do
      expect(client).to receive(:purge_path).with('/specs.4.8.gz')
      subject
    end

    it 'purges prerelease specs' do
      expect(client).to receive(:purge_path).with('/prerelease_specs.4.8.gz')
      subject
    end

    context 'with a nil client' do
      let(:client) { nil }

      it 'does nothing' do
        expect { subject }.to_not raise_error
      end
    end
  end

  describe '.purge_gem' do
    let(:name) { 'bundler-1.0.0' }
    subject { cache.purge_gem(name) }

    it 'purges gemspec' do
      expect(client).to receive(:purge_path)
        .with('/quick/Marshal.4.8/bundler-1.0.0.gemspec.rz')
      subject
    end

    it 'purges gem' do
      expect(client).to receive(:purge_path)
        .with('/gems/bundler-1.0.0.gem')
      subject
    end

    it "purges memcached gem" do
      cache.memcached_client.set("deps/v1/#{name}", "omg!")
      expect(cache.memcached_client.get("deps/v1/#{name}")).to_not be_nil
      subject
      expect(cache.memcached_client.get("deps/v1/#{name}")).to be_nil
    end

    context 'with a nil client' do
      let(:client) { nil }

      it 'does nothing' do
        expect { subject }.to_not raise_error
      end
    end
  end

  describe '.purge_memory_cache' do
    let(:name) { 'bundler-1.0.0' }
    subject { cache.purge_memory_cache(name) }

    it 'purge memcached gem api' do
      cache.memcached_client.set("deps/v1/#{name}", "omg!")
      expect(cache.memcached_client.get("deps/v1/#{name}")).to_not be_nil
      subject
      expect(cache.memcached_client.get("deps/v1/#{name}")).to be_nil
    end

    it 'purge memcached gem info' do
      cache.memcached_client.set("info/#{name}", "omg!")
      expect(cache.memcached_client.get("info/#{name}")).to_not be_nil
      subject
      expect(cache.memcached_client.get("info/#{name}")).to be_nil
    end

    it 'purge memcached gem names' do
      cache.memcached_client.set("names", "omg!")
      expect(cache.memcached_client.get("names")).to_not be_nil
      subject
      expect(cache.memcached_client.get("names")).to be_nil
    end
  end
end
