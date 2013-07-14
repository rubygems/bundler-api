require 'spec_helper'
require 'bundler_api/update/atomic_counter'

describe BundlerApi::AtomicCounter do
  let(:counter) { BundlerApi::AtomicCounter.new }

  it "starts at 0" do
    expect(counter.count).to eq(0)
  end

  it "increments by 1" do
    counter.increment

    expect(counter.count).to eq(1)
  end

  it "can increment more than once" do
    num = 12
    num.times { counter.increment }

    expect(counter.count).to eq(12)
  end

  # need to run this test in JRuby
  it "is atomic" do
    max     = 10
    # need to create a new counter for JRuby
    counter = BundlerApi::AtomicCounter.new

    (1..max).map do
      Thread.new { counter.increment }
    end.each(&:join)

    expect(counter.count).to eq(max)
  end
end
