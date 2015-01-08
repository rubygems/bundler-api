require 'bundler_api/metriks'
require 'bundler_api/redis'

class BundlerApi::AgentReporting
  UA_REGEX = %r{^
    bundler/(?<bundler_version>\d\.\d\.\d)\s
    rubygems/(?<gem_version>\d\.\d\.\d)\s
    ruby/(?<ruby_version>\d\.\d\.\d)\s
    \((?<arch>.*)\)\s
    command/(?<command>\w+)\s
    (?:options/(?<options>\S+)\s)?
    (?<id>.*)
  }x

  def initialize(app)
    @app = app
  end

  def call(env)
    report_user_agent(env['HTTP_USER_AGENT'])
    @app.call(env)
  end

private

  def report_user_agent(ua_string)
    return unless ua_match = UA_REGEX.match(ua_string)
    return if known_id?(ua_match['id'])

    keys = [ "versions.bundler.#{ ua_match['bundler_version'] }",
      "versions.rubygems.#{ ua_match['gem_version'] }",
      "versions.ruby.#{ ua_match['ruby_version'] }",
      "archs.#{ ua_match['arch'] }",
      "commands.#{ ua_match['command'] }"
    ]

    if ua_match['options']
      keys += ua_match['options'].split(",").map { |k| "options.#{ k }" }
    end

    keys.each { |metric| Metriks.counter(metric).increment }
  end

  def known_id?(id)
    if BundlerApi.redis.exists(id)
      true
    else
      BundlerApi.redis.setex(id, 120, true)
      false
    end
  end
end
