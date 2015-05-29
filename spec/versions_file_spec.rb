require 'sequel'
require 'tempfile'
require 'spec_helper'
require 'bundler_api/versions_file'
require 'support/gem_builder'

describe BundlerApi::GemInfo do
  let(:db)       { $db }
  let(:builder)  { GemBuilder.new(db) }
  let(:versions_file) { BundlerApi::VersionsFile.new(db) }

  describe "#update"  do
    before do
      a = builder.create_rubygem("a")
      b = builder.create_rubygem("b")
      builder.create_version(a, "a", "0.0.1")
      builder.create_version(b, "b", "0.0.2")
      builder.create_version(b, "b", "0.1.1", "java")
      builder.create_version(b, "b", "0.1.2")
    end

    it "return a hash of gems and versions" do
      file = Tempfile.new('versions.list')
      versions_file.update(file.path)
      file.rewind
      expect(file.read).to match(/\d+\n---\na 0\.0\.1\nb 0\.0\.2,0\.1\.1-java,0\.1\.2/)
    end
  end
end
