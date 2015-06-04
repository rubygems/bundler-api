require 'sequel'
require 'tempfile'
require 'spec_helper'
require 'bundler_api/versions_file'
require 'support/gem_builder'
require 'support/versions_file'

describe BundlerApi::GemInfo do
  let(:db)       { $db }
  let(:builder)  { GemBuilder.new(db) }
  let(:versions_file) { BundlerApi::VersionsFile.new(db) }
  let (:yesterday) { DateTime.now - 86400 }
  let (:tomorrow) { DateTime.now + 86400 }
  let (:file_creation_time) { Time.now }

  before do
    a = builder.create_rubygem("a")
    b = builder.create_rubygem("b")
    builder.create_version(a, "a", "0.0.1", "ruby", true, yesterday)
    builder.create_version(b, "b", "0.0.2", "ruby", true, yesterday)
    builder.create_version(b, "b", "0.1.1", "java", true, yesterday)
    builder.create_version(b, "b", "0.1.2", "ruby", true, yesterday)
  end
  let (:file_contents) { "0123456789\n---\na 0.0.1\nb 0.0.2,0.1.1-java,0.1.2" }

  describe "#create"  do
    it "return a hash of gems and versions" do
      file = Tempfile.new('versions.list')
      with_versions_file file.path do
        versions_file.create
        file.rewind
        expect(file.read).to match(/\d+\n---\na 0\.0\.1\nb 0\.0\.2,0\.1\.1-java,0\.1\.2/)
      end
    end
  end

  describe "#update" do
    before do
      b = builder.rubygem_id("b")
      c = builder.create_rubygem("c")
      builder.create_version(b, "b", "0.2.0", "rbx", true, tomorrow)
      builder.create_version(b, "b", "0.2.0", "ruby", true, tomorrow)
      builder.create_version(c, "c", "1.0.0", "ruby", true, tomorrow)
    end

    it "add new versions to file" do
      file = Tempfile.new('versions.list')
      file.write file_contents
      file.rewind
      with_versions_file file.path do
        versions_file.update
        file.rewind
        expect(file.read).to eq(file_contents + "\nb 0.2.0,0.2.0-rbx\nc 1.0.0")
      end
    end
  end

  describe "#with_new_gems" do
    context "is has nothing new" do
      before { File.any_instance.stub(:read).and_return("file_contents") }
      before { File.any_instance.stub(:mtime).and_return(file_creation_time) }

      it "return the same content from versions.list file" do
        expect(versions_file.with_new_gems).to eq(versions_file.send(:content))
      end
    end

    context "it has something new" do
      before { File.any_instance.stub(:read).and_return(file_contents) }
      before { File.any_instance.stub(:mtime).and_return(file_creation_time) }
      before do
        b = builder.rubygem_id("b")
        c = builder.create_rubygem("c")
        builder.create_version(b, "b", "0.2.0", "rbx", true, tomorrow)
        builder.create_version(b, "b", "0.2.0", "ruby", true, tomorrow)
        builder.create_version(c, "c", "1.0.0", "ruby", true, tomorrow)
      end

      it "return the content from versions.list with new gems on bottom" do
        expect(versions_file.with_new_gems).to eq(file_contents + "\nb 0.2.0,0.2.0-rbx\nc 1.0.0")
      end
    end
  end
end
