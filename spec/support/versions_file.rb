require 'spec_helper'
require 'bundler_api/versions_file'

def with_versions_file(path)
  old_path = BundlerApi::VersionsFile::PATH
  BundlerApi::VersionsFile.send(:remove_const, 'PATH')
  BundlerApi::VersionsFile.const_set('PATH', path)
  yield
  BundlerApi::VersionsFile.send(:remove_const, 'PATH')
  BundlerApi::VersionsFile.const_set('PATH', old_path)
end
