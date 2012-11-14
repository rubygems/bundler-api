require 'sinatra/base'
require 'artifice'
require_relative '../spec_helper'
require_relative '../../lib/bundler_api/update/job'
require_relative '../../lib/bundler_api/update/atomic_counter'

class GemspecGenerator < Sinatra::Base
  get "/quick/Marshal.4.8/*" do
    name, version, platform = params[:splat].first.sub('.gemspec.rz', '').split('-')
    platform ||= 'ruby'
    Gem.deflate(Marshal.dump(generate_gemspec(name, version, platform)))
  end

  private
  def generate_gemspec(name, version, platform = 'ruby')
eval(<<GEMSPEC)
Gem::Specification.new do |s|
  s.name = "#{name}"
  s.version = "#{version}"
  s.platform = "#{platform}"

  s.authors = ["Terence Lee"]
  s.date = "2010-10-24"
  s.description = "Foo"
  s.email = "foo@example.com"
  s.homepage = "http://www.foo.com"
  s.require_paths = ["lib"]
  s.rubyforge_project = "foo"
  s.summary = "Foo"
end
GEMSPEC
  end
end

describe BundlerApi::Job do
  let(:db)      { Sequel.connect(ENV['TEST_DATABASE_URL']) }
  let(:builder) { GemBuilder.new(db) }
  let(:counter) { BundlerApi::Counter.new }
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
      payload = BundlerApi::Payload.new("foo", Gem::Version.new("1.0"), "ruby")
      job     = BundlerApi::Job.new(db, payload, mutex, counter)

      job.run

      gem_exists?(db, 'foo')
    end

    it "creates different platform rubygems" do
      %w(ruby java).each do |platform|
        payload = BundlerApi::Payload.new("foo", Gem::Version.new("1.0"), platform)
        job     = BundlerApi::Job.new(db, payload, mutex, counter)
        job.run
      end

      gem_exists?(db, 'foo')
      gem_exists?(db, 'foo', '1.0', 'java')
    end
  end
end
