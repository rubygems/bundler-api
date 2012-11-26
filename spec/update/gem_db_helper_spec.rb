require_relative '../spec_helper'
require_relative '../../lib/bundler_api/update/gem_db_helper'
require_relative '../../lib/bundler_api/gem_helper'

describe BundlerApi::GemDBHelper do
  let(:db)        { Sequel.connect(ENV['TEST_DATABASE_URL']) }
  let(:gem_cache) { Hash.new }
  let(:mutex)     { nil }
  let(:helper)    { BundlerApi::GemDBHelper.new(db, gem_cache, mutex) }
  around(:each) do |example|
    db.transaction(:rollback => :always) { example.run }
  end

  describe "#gem_exists?" do
    let(:payload) { BundlerApi::GemHelper.new("foo", Gem::Version.new("1.0"), "ruby", false) }

    context "if the gem exists" do
      before do
        rubygem = db[:rubygems].insert(name: "foo")
        version = db[:versions].insert(rubygem_id: rubygem, number: "1.0", platform: "ruby", indexed: true)
      end

      it "returns the rubygems and versions id" do
        result = helper.exists?(payload)

        expect(result[:rubygem_id]).to be_true
        expect(result[:version_id]).to be_true
      end
    end

    context "if the gem does not exst" do
      it "returns nil" do
        expect(helper.exists?(payload)).to be_nil
      end
    end
  end
end
