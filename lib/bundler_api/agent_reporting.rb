require 'bundler_api/metriks'

class BundlerApi::AgentReporting
  UA_REGEX = %r{^
    bundler/(?<bundler_version>\d\.\d\.\d)\s
    rubygems/(?<gem_version>\d\.\d\.\d)\s
    ruby/(?<ruby_version>\d\.\d\.\d)\s
    \((?<arch>.*)\)\s
    command/(?<command>\w+)
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
    [ "versions.bundler.#{ ua_match['bundler_version'] }",
      "versions.rubygems.#{ ua_match['gem_version'] }",
      "versions.ruby.#{ ua_match['ruby_version'] }",
      "archs.#{ ua_match['arch'] }",
      "commands.#{ ua_match['command'] }"
    ].each do |metric|
      Metriks.counter(metric).increment()
    end
  end
end
