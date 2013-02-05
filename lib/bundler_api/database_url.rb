require 'uri'
require_relative '../bundler_api'

class BundlerApi::DatabaseUrl
  def self.url(url)
    if RUBY_ENGINE == 'jruby'
      uri = URI.parse(url)

      URI::Generic.new("jdbc:postgresql",
                       "",
                       uri.host,
                       uri.port,
                       nil,
                       uri.path,
                       nil,
                       "user=#{uri.user}&password=#{uri.password}",
                       nil).to_s
    else
      url
    end
  end
end
