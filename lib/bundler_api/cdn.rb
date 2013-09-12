require 'fastly'

class BundlerApi::Cdn
  def self.purge_specs(client = self.client)
    return unless client
    client.purge '/latest_specs.4.8.gz'
    client.purge '/specs.4.8.gz'
    client.purge '/prerelease_specs.4.8.gz'
  end

  def self.purge_gem(gem, client = self.client)
    return unless client
    client.purge "/quick/Marshal.4.8/#{gem.full_name}.gemspec.rz"
    client.purge "/quick/Marshal.4.8/#{gem.full_name}.gem"
  end

  def self.client
    return unless api_key
    @client ||= Fastly.new(api_key: api_key)
  end

  def self.api_key
    ENV['FASTLY_API_KEY']
  end
end
