require 'monitor'
require 'timeout'
require 'spec_helper'
require 'bundler_api/update/consumer_pool'

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

  class FirstJob
    attr_reader :ran

    def initialize(test_latch, job_latch)
      @test_latch = test_latch
      @job_latch  = job_latch
      @ran        = false
    end

    def run
      @test_latch.release
      @job_latch.wait
      @ran = true
    end
  end

  class SecondJob
    attr_reader :ran

    def initialize(latch)
      @latch = latch
      @ran   = false
    end

    def run
      @latch.release
      @ran = true
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

  it "works concurrently" do
    job_latch  = Latch.new
    test_latch = Latch.new
    pool  = BundlerApi::ConsumerPool.new(2)
    job1  = FirstJob.new(test_latch, job_latch)
    job2  = SecondJob.new(job_latch)

    pool.start
    pool.enq(job1)
    # ensure the first job is executing
    # requires second job to finish
    Timeout.timeout(1) { test_latch.release }
    pool.enq(job2)
    pool.poison

    pool.join

    expect(job1.ran).to be true
    expect(job2.ran).to be true
  end
end
