require_relative '../spec_helper'
require_relative '../../lib/bundler_api/update/consumer_pool'

describe BundlerApi::ConsumerPool do
  class TestJob
    @@counter = 0

    def self.counter
      @@counter
    end

    def run
      @@counter += 1
    end
  end

  it "stops the pool" do
    pool = BundlerApi::ConsumerPool.new(1)
    pool.start
    pool.poison
    pool.enq(TestJob.new)
    pool.join

    expect(TestJob.counter).to eq(0)
  end

  it "processes jobs" do
    pool = BundlerApi::ConsumerPool.new(1)
    pool.enq(TestJob.new)
    pool.start
    pool.poison
    pool.join

    expect(TestJob.counter).to eq(1)
  end
end
