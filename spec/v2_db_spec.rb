require 'spec_helper'
require 'bundler_api/v2_db'
require 'support/gem_builder'

describe BundlerApi::V2DB do
  let(:db)      { $db }
  let(:builder) { GemBuilder.new(db) }
  let(:v2db)    { BundlerApi::V2DB.new(db) }

  describe "#names" do
    before do
      builder.create_rubygem("a")
      builder.create_rubygem("c")
      builder.create_rubygem("b")
      builder.create_rubygem("d")
    end

    it "should return the list back in order" do
      expect(v2db.names).to eq(%w(a b c d))
    end
  end
end
