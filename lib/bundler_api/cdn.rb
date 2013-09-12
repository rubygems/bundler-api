require 'fastly'

class BundlerApi::Cdn
  def self.purge_specs(client = self.client)
    return unless client
    client.purge '/latest_specs.4.8.gz'
    client.purge '/specs.4.8.gz'
    client.purge '/prerelease_specs.4.8.gz'
    print "Purging /latest_specs.4.8.gz /specs.4.8.gz /prerelease_specs.4.8.gz\n"
  end

  def self.purge_gem(gem, client = self.client)
    return unless client
    client.purge "/quick/Marshal.4.8/#{gem.full_name}.gemspec.rz"
    client.purge "/quick/Marshal.4.8/#{gem.full_name}.gem"
    print "Purging /quick/Marshal.4.8/#{gem.full_name}.gemspec.rz /quick/Marshal.4.8/#{gem.full_name}.gem\n"
  end

  def self.client
    return unless api_key
    @client ||= Fastly.new(api_key: api_key)
  end

  def self.api_key
    ENV['FASTLY_API_KEY']
  end
end
