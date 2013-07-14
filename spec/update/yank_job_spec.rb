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
      let(:payload)   { BundlerApi::GemHelper.new('foo', '1.0', 'ruby') }
      let(:payload2)  { BundlerApi::GemHelper.new('foo', '1.1', 'ruby') }
      let(:gem_cache) {
        {
          payload.full_name  => 1,
          payload2.full_name => 2
        }
      }

      it "should remove the gem from the cache" do
        job.run

        expect(gem_cache).to eq({payload2.full_name => 2})
      end
    end

    context "when the platform is jruby" do
      let(:payload)   { BundlerApi::GemHelper.new('foo', '1.0', 'jruby') }
      let(:gem_cache) {
        gem_helper = BundlerApi::GemHelper.new('foo', '1.0', 'jruby')
        {
          gem_helper.full_name => 1
        }
      }

      it "should remove the gem from the cache" do
        job.run

        expect(gem_cache).to eq({})
      end
    end
  end
end
