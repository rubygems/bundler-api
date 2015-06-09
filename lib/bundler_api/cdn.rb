require 'net/http'

class BundlerApi::Cdn
  def self.purge_specs(client = self.client)
    return unless client
    threads = []
    threads << Thread.new { client.purge_key  'dependencies' }
    threads << Thread.new { client.purge_path '/latest_specs.4.8.gz' }
    threads << Thread.new { client.purge_path '/specs.4.8.gz' }
    threads << Thread.new { client.purge_path '/prerelease_specs.4.8.gz' }
    threads.each { |t| t.join }
    print "Purging dependencies /latest_specs.4.8.gz /specs.4.8.gz /prerelease_specs.4.8.gz\n"
  end

  def self.purge_gem_by_name(name, client = self.client)
    return unless client
    threads = []
    threads << Thread.new { client.purge_path "/quick/Marshal.4.8/#{name}.gemspec.rz"}
    threads << Thread.new { client.purge_path "/gems/#{name}.gem" }
    threads.each { |t| t.join }
    print "Purging /quick/Marshal.4.8/#{name}.gemspec.rz /gems/#{name}.gem\n"
  end

  def self.purge_gem(gem, client = self.client)
    purge_gem_by_name gem.full_name, client
  end

  def self.client
    return unless service_id && base_url
    Client.new(service_id, base_url, api_key)
  end

  def self.service_id
    @service_id ||= ENV['FASTLY_SERVICE_ID']
  end

  def self.base_url
    @base_url ||= ENV['FASTLY_BASE_URL']
  end

  def self.api_key
    @api_key ||= ENV['FASTLY_API_KEY']
  end

  Client = Struct.new(:service_id, :base_url, :api_key) do
    def purge_key(key)
      uri = URI("https://api.fastly.com/service/#{service_id}/purge/#{key}")
      http(uri).post uri.request_uri, nil, "Fastly-Key" => api_key
    end

    def purge_path(path)
      uri = URI("#{base_url}#{path}")
      http(uri).send_request 'PURGE', uri.path, nil, "Fastly-Key" => api_key
    end

    def http(uri)
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        http.use_ssl     = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end
    end
  end
end
