require 'uri'
require 'net/http'
require 'bundler_api'
require 'json'

class BundlerApi::HTTPError < RuntimeError
end

class BundlerApi::GemHelper < Struct.new(:name, :version, :platform, :prerelease)
  RUBYGEMS_URL = ENV['RUBYGEMS_URL'] || "https://www.rubygems.org"

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

  def checksum
    @checksum
  end

  def download_spec(base = nil)
    base ||= ENV.fetch("DOWNLOAD_BASE", "https://rubygems.global.ssl.fastly.net")
    url = "#{base}/quick/Marshal.4.8/#{full_name}.gemspec.rz"
    set_checksum
    @mutex.synchronize do
      @gemspec ||= Marshal.load(Gem.inflate(fetch(url)))
    end
  end

private

  def set_checksum
    # TODO: Change this to the new rubygems call when accepted
    url = "#{RUBYGEMS_URL}/api/v1/versions/#{name}.json"
    resp = JSON.parse(fetch(url))
    version_info = resp.find { |e| e['number'] == version.to_s }

    if version_info
      warn "WARNING: Gem #{name}-#{version} has no checksum!" unless version_info['sha']
      @checksum = version_info['sha']
    else
      warn "WARNING: Can't find gem #{name}-#{version} in JSON from #{url}" unless version_info
    end
  end

  def fetch(url, redirects = 0, tries = [])
    raise BundlerApi::HTTPError, "Too many redirects #{url}" if redirects >= REDIRECT_LIMIT
    raise BundlerApi::HTTPError, "Could not download #{url} (#{tries.join(", ")})" if tries.size >= TRY_LIMIT

    uri      = URI.parse(url)
    response = begin
      Net::HTTP.get_response(uri)
    rescue => e
      "(#{url}) #{e}"
    end

    case response
    when Net::HTTPRedirection
      fetch(response["location"], redirects + 1)
    when Net::HTTPSuccess
      response.body
    else
      tries << response
      exp = tries.size
      exp *= 2 if response.is_a?(Net::HTTPTooManyRequests)
      sleep(3 ** exp)
      fetch(url, redirects, tries)
    end
  end
end
