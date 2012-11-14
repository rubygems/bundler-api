require_relative '../../bundler_api'
BundlerApi::Payload = Struct.new(:name, :version, :platform, :prerelease)
