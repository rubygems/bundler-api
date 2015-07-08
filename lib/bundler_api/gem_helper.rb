require 'uri'
require 'net/http'
require 'bundler_api'

class BundlerApi::HTTPError < RuntimeError
end

class BundlerApi::GemHelper < Struct.new(:name, :version, :platform, :prerelease)
  REDIRECT_LIMIT = 5
  TRY_LIMIT      = 4

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

  def download_spec(base = ENV['DOWNLOAD_BASE'] || "http://production.s3.rubygems.org")
    @mutex.synchronize { return @gemspec if @gemspec }
    url   = "#{base}/quick/Marshal.4.8/#{full_name}.gemspec.rz"

    @mutex.synchronize do
      @gemspec = Marshal.load(Gem.inflate(fetch(url)))
    end
  end

private
  def fetch(url, redirects = 0, tries = 0)
    raise BundlerApi::HTTPError, "Too many redirects #{url}" if redirects >= REDIRECT_LIMIT
    raise BundlerApi::HTTPError, "Could not download #{url}" if tries >= TRY_LIMIT

    uri      = URI.parse(url)
    response = nil
    begin
      response = Net::HTTP.get_response(uri)
    rescue StandardError => e
      puts "#{e} #{url}"
    end

    case response
    when Net::HTTPRedirection
      fetch(response["location"], redirects + 1)
    when Net::HTTPSuccess
      response.body
    else
      exp = tries - 1
      sleep(2 ** exp) if exp > 0
      fetch(url, redirects, tries + 1)
    end
  end
end
