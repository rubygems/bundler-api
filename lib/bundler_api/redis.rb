require 'redis'

module BundlerApi
  class << self
    attr_accessor :redis
  end
end

BundlerApi.redis = Redis.new(url: ENV[ENV['REDIS_ENV']])