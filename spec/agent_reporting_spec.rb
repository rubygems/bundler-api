require 'spec_helper'
require 'bundler_api/agent_reporting'

describe BundlerApi::AgentReporting do
  class FakeMetriks
    attr_accessor :values, :key
    def initialize; @values = Hash.new { |hash, key| hash[key] = 0 } end
    def mark;       @values[key] += 1                                end
  end

  let(:app)        { double(call: true) }
  let(:middleware) { described_class.new(app) }
  let(:metriks)    { FakeMetriks.new }
  let(:redis)      { double(exists: false, setex: true) }
  let(:env)        { {'HTTP_USER_AGENT' => ua} }
  let(:ua) do
    [ 'bundler/1.7.3',
      'rubygems/2.4.1',
      'ruby/2.1.2',
      '(x86_64-apple-darwin13.2.0)',
      'command/update',
      'options/jobs,without,build.mysql',
      'ci/jenkins,ci',
      '9d16bd9809d392ca' ].join(' ')
  end

  before do
    Metriks.stub(:meter) { |key| metriks.key = key; metriks }
    BundlerApi.stub(:redis => redis)
    middleware.call(env)
  end

  context "with options" do
    describe 'reporting metrics (valid UA)' do
      it 'should report the right values' do
        expect( metriks ).to be_incremented_for('versions.bundler.1.7.3')
        expect( metriks ).to be_incremented_for('versions.rubygems.2.4.1')
        expect( metriks ).to be_incremented_for('versions.ruby.2.1.2')
        expect( metriks ).to be_incremented_for('commands.update')
        expect( metriks ).to be_incremented_for('archs.x86_64-apple-darwin13.2.0')
        expect( metriks ).to be_incremented_for('options.jobs')
        expect( metriks ).to be_incremented_for('options.without')
        expect( metriks ).to be_incremented_for('options.build.mysql')
        expect( metriks ).to be_incremented_for('cis.jenkins')
        expect( metriks ).to be_incremented_for('cis.ci')
      end
    end

    describe 'reporting metrics (invalid UA)' do
      let(:ua) { 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; WOW64; Trident/6.0)' }
      it 'should not report anything' do
        expect( metriks.values ).to be_empty
      end
    end
  end

  context "without options" do
    let(:ua) do
      [ 'bundler/1.7.3',
        'rubygems/2.4.1',
        'ruby/2.1.2',
        '(x86_64-apple-darwin13.2.0)',
        'command/update',
        'ci/semaphore',
        '9d16bd9809d392ca' ].join(' ')
    end

    describe 'weird version number' do
      let(:ua) { super().sub('bundler/1.7.3', 'bundler/1.10.4.beta.1') }
      it 'increments double-digit bundler versions' do
        expect( metriks ).to be_incremented_for('versions.bundler.1.10.4.beta.1')
      end
    end

    describe 'reporting metrics (valid UA, first time)' do
      it 'should report the right values' do
        expect( metriks ).to be_incremented_for('versions.bundler.1.7.3')
        expect( metriks ).to be_incremented_for('versions.rubygems.2.4.1')
        expect( metriks ).to be_incremented_for('versions.ruby.2.1.2')
        expect( metriks ).to be_incremented_for('commands.update')
        expect( metriks ).to be_incremented_for('archs.x86_64-apple-darwin13.2.0')
        expect( metriks ).to be_incremented_for('cis.semaphore')
      end
    end

    describe 'reporting metrics (valid UA, return customer)' do
      let(:redis) { double(exists: true) }

      it 'should not report anything' do
        expect( metriks.values ).to be_empty
      end
    end

    describe 'reporting metrics (invalid UA)' do
      let(:ua) { 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; WOW64; Trident/6.0)' }
      it 'should not report anything' do
        expect( metriks.values ).to be_empty
      end
    end
  end

  context "when Redis breaks" do
    before do
      redis.stub(:exists).and_raise(Redis::CannotConnectError)
    end

    it "should not raise an exception" do
      expect { middleware.call(env) }.not_to raise_error
    end
  end
end
