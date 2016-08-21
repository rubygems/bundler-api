require 'uri'
require 'net/http'
require 'bundler_api'
require 'json'

class BundlerApi::HTTPError < RuntimeError
end

class BundlerApi::GemHelper < Struct.new(:name, :version, :platform, :prerelease)
  RUBYGEMS_URL = ENV['RUBYGEMS_URL'] || "https://rubygems.org"

  REDIRECT_LIMIT = 5
  TRY_LIMIT      = 4
  TRY_BACKOFF    = 3

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

  def download_spec
    url = download_gem_url("quick/Marshal.4.8/#{full_name}.gemspec.rz")
    @mutex.synchronize do
      @gemspec ||= Marshal.load(Gem.inflate(fetch(url)))
    end
  rescue => e
    STDERR.puts "[Error] Downloading gemspec #{full_name} failed! #{e.class}: #{e.message}"
    STDERR.puts e.backtrace.join("\n  ")
  end

  def download_checksum
    url = File.join(RUBYGEMS_URL, "/api/v2/rubygems/#{name}/versions/#{version}.json")
    response = fetch(url)
    return warn("WARNING: Can't find gem #{name}-#{version} at #{url}") if response.empty?
    version_info = JSON.parse(response)
    return warn("WARNING: Gem #{name}-#{version} has no checksum!") if version_info['sha'].nil?

    version_info['sha']
  end

private

  def fetch(url, redirects = 0, tries = [])
    raise BundlerApi::HTTPError, "Too many redirects #{url}" if redirects >= REDIRECT_LIMIT
    raise BundlerApi::HTTPError, "Could not download #{url} (#{tries.join(", ")})" if tries.size >= TRY_LIMIT

    uri = URI.parse(url)
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
      sleep(TRY_BACKOFF ** exp)
      fetch(url, redirects, tries)
    end
  end

  def download_gem_url(path = nil)
    @base_url ||= ENV.fetch("DOWNLOAD_BASE", "https://rubygems.global.ssl.fastly.net")
    File.join(@base_url, path || '')
  end
end
