require 'uri'
require 'net/http'
require_relative '../bundler_api'
require_relative 'metriks'

class BundlerApi::HTTPError < RuntimeError
end

class BundlerApi::GemHelper < Struct.new(:name, :version, :platform, :prerelease)
  REDIRECT_LIMIT = 5

  def initialize(*)
    super
    @mutex   = Mutex.new
    @gemspec = nil
  end

  def full_name
    full_name = "#{name}-#{version}"
    full_name << "-#{platform}" if platform != 'ruby'

    full_name
  end

  def download_spec(base = "http://rubygems.org")
    @mutex.synchronize { return @gemspec if @gemspec }
    timer = Metriks.timer('job.download_spec').time
    url   = "#{base}/quick/Marshal.4.8/#{full_name}.gemspec.rz"

    @mutex.synchronize do
      @gemspec = Marshal.load(Gem.inflate(fetch(url)))
    end
  ensure
    timer.stop if timer
  end

  private
  def fetch(uri, tries = 0)
    raise BundlerApi::HTTPError, "Too many redirects" if tries >= REDIRECT_LIMIT

    uri      = URI.parse(uri)
    response = Net::HTTP.get_response(uri)

    case response
    when Net::HTTPRedirection
      fetch(response["location"], tries + 1)
    when Net::HTTPSuccess
      response.body
    else
      raise BundlerApi::HTTPError, "Could not download #{uri}, #{response.class}"
    end
  end
end
