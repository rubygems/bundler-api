module BundlerApi
  class Env
    def self.load
      return unless local_env?
      require 'dotenv'
      Dotenv.load '.env.local', '.env'
    end

    def self.local_env?
      ENV['RACK_ENV'].nil? ||
        ENV['RACK_ENV'] == 'development' or
        ENV['RACK_ENV'] == 'test'
    end
  end
end

BundlerApi::Env.load
