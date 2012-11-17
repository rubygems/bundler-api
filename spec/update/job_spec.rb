require 'sinatra/base'
require 'artifice'
require_relative '../spec_helper'
require_relative '../support/artifice_apps'
require_relative '../../lib/bundler_api/update/job'
require_relative '../../lib/bundler_api/update/atomic_counter'

describe BundlerApi::Job do
  let(:db)      { Sequel.connect(ENV['TEST_DATABASE_URL']) }
  let(:builder) { GemBuilder.new(db) }
  let(:counter) { BundlerApi::AtomicCounter.new }
  let(:mutex)   { Mutex.new }
  around(:each) do |example|
    db.transaction(:rollback => :always) { example.run }
  end

  describe "#run" do
    before do
      Artifice.activate_with(GemspecGenerator)
    end

    after do
      Artifice.deactivate
    end

    def gem_exists?(db, name, version = '1.0', platform = 'ruby')
      expect(db[<<-SQL, 'foo', version, platform].count).to eq(1)
SELECT *
FROM rubygems, versions
WHERE rubygems.id = versions.rubygem_id
  AND rubygems.name = ?
  AND versions.number = ?
  AND versions.platform = ?
SQL
    end

    it "creates a rubygem if it doesn't exist" do
      payload = BundlerApi::GemHelper.new("foo", Gem::Version.new("1.0"), "ruby")
      job     = BundlerApi::Job.new(db, payload, mutex, counter)

      job.run

      gem_exists?(db, 'foo')
    end

    it "creates different platform rubygems" do
      %w(ruby java).each do |platform|
        payload = BundlerApi::GemHelper.new("foo", Gem::Version.new("1.0"), platform)
        job     = BundlerApi::Job.new(db, payload, mutex, counter)
        job.run
      end

      gem_exists?(db, 'foo')
      gem_exists?(db, 'foo', '1.0', 'java')
    end

    it "doesn't dupe rubygems" do
      %w(ruby java ruby).each do |platform|
        payload = BundlerApi::GemHelper.new("foo", Gem::Version.new("1.0"), platform)
        job     = BundlerApi::Job.new(db, payload, mutex, counter)
        job.run
      end

      gem_exists?(db, 'foo')
      gem_exists?(db, 'foo', '1.0', 'java')
    end

    context "when the index platform is jruby" do
      before do
        Artifice.activate_with(GemspecJrubyGenerator)
      end

      after do
        Artifice.deactivate
      end

      it "handles when platform in spec is different" do
        jobs = 2.times.map do
          payload = BundlerApi::GemHelper.new("foo", Gem::Version.new("1.0"), 'jruby')
          BundlerApi::Job.new(db, payload, mutex, counter)
        end

        jobs.first.run
        expect { jobs[1].run }.not_to raise_error(Sequel::DatabaseError)

        gem_exists?(db, 'foo', '1.0', 'java')
      end

      it "sets the indexed attribute to true" do
        jobs = 2.times.map do
          payload = BundlerApi::GemHelper.new("foo", Gem::Version.new("1.0"), 'jruby')
          BundlerApi::Job.new(db, payload, mutex, counter)
        end
        jobs.first.run
        version_id = db[<<-SQL, 'foo', '1.0', 'java'].first[:id]
          SELECT versions.id
          FROM rubygems, versions
          WHERE rubygems.id = versions.rubygem_id
            AND rubygems.name = ?
            AND versions.number = ?
            AND versions.platform = ?
SQL
        db[:versions].where(id: version_id).update(indexed: false)
        jobs[1].run

        gem_exists?(db, 'foo', '1.0', 'java')
        expect(db[:versions].filter(id: version_id).select(:indexed).first[:indexed]).to be_true
      end
    end
  end
end
