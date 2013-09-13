require 'spec_helper'
require 'support/artifice_apps'
require 'bundler_api/update/yank_job'

describe BundlerApi::YankJob do
  let(:mutex) { Mutex.new }
  let(:job)   { BundlerApi::YankJob.new(gem_cache, payload, mutex) }

  describe "#run" do
    before do
      Artifice.activate_with(GemspecGenerator)
    end

    after do
      Artifice.deactivate
    end

    context "when the platform is ruby" do
      let(:payload) { BundlerApi::GemHelper.new('foo', '1.0', 'ruby') }
      let(:gem_cache)    {
        {
          BundlerApi::GemHelper.new('foo', '1.0', 'ruby') => 1,
          BundlerApi::GemHelper.new('foo', '1.1', 'ruby') => 2
        }
      }

      it "should remove the gem from the cache" do
        job.run

        expected = { BundlerApi::GemHelper.new('foo', '1.1', 'ruby') => 2 }
        expect(gem_cache).to eq(expected)
      end

      it 'returns number of gems deleted' do
        expect(job.run).to eq(1)
      end
    end

    context "when the platform is jruby" do
      let(:payload)   { BundlerApi::GemHelper.new('foo', '1.0', 'jruby') }
      let(:gem_cache) {
        { BundlerApi::GemHelper.new('foo', '1.0', 'jruby') => 1 }
      }

      it "should remove the gem from the cache" do
        job.run

        expect(gem_cache).to eq({})
      end
    end
  end
end
