require_relative '../spec_helper'
require_relative '../../lib/bundler_api/update/counter'

describe BundlerApi::Counter do
  let(:counter) { BundlerApi::Counter.new }

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
end
