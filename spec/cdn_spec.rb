require 'spec_helper'
require 'bundler_api/cdn'

describe BundlerApi::Cdn do
  let(:client) { double(:client, purge_path: nil, purge_key: nil) }

  describe '.purge_specs' do
    subject { BundlerApi::Cdn.purge_specs(client) }

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

  describe '.purge_versions_list' do
    subject { BundlerApi::Cdn.purge_versions_list(client) }
    it 'purges versions' do
      expect(client).to receive(:purge_path).with("/versions")
      subject
    end
  end

  describe '.purge_gem_by_name' do
    let(:name) { 'bundler-1.0.0' }
    subject { BundlerApi::Cdn.purge_gem_by_name(name, client) }

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

    context 'with a nil client' do
      let(:client) { nil }

      it 'does nothing' do
        expect { subject }.to_not raise_error
      end
    end
  end

  describe '.purge_gem' do
    let(:gem) { double(:gem, full_name: 'bundler-1.0.0') }
    subject { BundlerApi::Cdn.purge_gem(gem, client) }

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

    context 'with a nil client' do
      let(:client) { nil }

      it 'does nothing' do
        expect { subject }.to_not raise_error
      end
    end
  end
end
