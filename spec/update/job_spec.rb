require 'sinatra/base'
require 'artifice'
require_relative '../spec_helper'
require_relative '../support/artifice_apps'
require_relative '../../lib/bundler_api/update/job'
require_relative '../../lib/bundler_api/update/atomic_counter'

describe BundlerApi::Job do
  let(:db)      { $db }
  let(:builder) { GemBuilder.new(db) }
  let(:counter) { BundlerApi::AtomicCounter.new }
  let(:mutex)   { Mutex.new }

  before do
    BundlerApi::Job.clear_cache
  end

  describe "#run" do
    before do
      Artifice.activate_with(GemspecGenerator)
    end

    after do
      Artifice.deactivate
    end

    def gem_exists?(db, name, version = '1.0', platform = 'ruby')
      expect(db[<<-SQL, name, version, platform].count).to eq(1)
SELECT *
FROM rubygems, versions
WHERE rubygems.id = versions.rubygem_id
  AND rubygems.name = ?
  AND versions.number = ?
  AND versions.platform = ?
SQL
    end

    def dependencies(name, version = "1.0", platform = "ruby")
      db[:dependencies].
        join(:versions, id: :version_id).
        join(:rubygems, id: :rubygem_id).
        filter(rubygems__name: name,
               versions__number: version,
               versions__platform: platform).
        all
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

    context "with gem dependencies" do
      let(:gem_payload) { BundlerApi::GemHelper.new("foo", Gem::Version.new("1.0"), "ruby") }
      let(:dep_payload) { BundlerApi::GemHelper.new("bar", Gem::Version.new("1.0"), "ruby") }
      let(:gem_job) { BundlerApi::Job.new(db, gem_payload, mutex, counter) }
      let(:dep_job) { BundlerApi::Job.new(db, dep_payload, mutex, counter) }

      context "when gem is added before the dependency" do
        before do
          gem_job.run
          dep_job.run
        end

        it "doesn't create any dependencies" do
          expect(dependencies("foo")).to be_empty
        end
      end

      context "when the dependency is added before the gem" do
        before do
          dep_job.run
          gem_job.run
        end

        it "creates the correct dependencies" do
          expect(dependencies("foo").length).to eq(1)
        end
      end
    end

    context "when the index platform is jruby" do
      it "handles when platform in spec is different" do
        jobs = 2.times.map do
          payload = BundlerApi::GemHelper.new("foo", Gem::Version.new("1.0"), 'jruby')
          BundlerApi::Job.new(db, payload, mutex, counter)
        end

        jobs.first.run
        expect { jobs[1].run }.not_to raise_error(Sequel::DatabaseError)

        gem_exists?(db, 'foo', '1.0', 'jruby')
      end

      it "sets the indexed attribute to true" do
        jobs = 2.times.map do
          payload = BundlerApi::GemHelper.new("foo", Gem::Version.new("1.0"), 'jruby')
          BundlerApi::Job.new(db, payload, mutex, counter)
        end
        jobs.first.run
        version_id = db[<<-SQL, 'foo', '1.0', 'jruby'].first[:id]
          SELECT versions.id
          FROM rubygems, versions
          WHERE rubygems.id = versions.rubygem_id
            AND rubygems.name = ?
            AND versions.number = ?
            AND versions.platform = ?
SQL
        db[:versions].where(id: version_id).update(indexed: false)
        jobs[1].run

        gem_exists?(db, 'foo', '1.0', 'jruby')
        expect(db[:versions].filter(id: version_id).select(:indexed).first[:indexed]).to be_true
      end
    end
  end
end
