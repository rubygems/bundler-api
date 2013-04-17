require 'pilfer/logger'
require 'pilfer/profiler'

module Pilfer
  class Middleware
    attr_accessor :app, :profiler

    def initialize(app)
      @app      = app
      @profiler = Pilfer::Profiler.new(reporter)
    end

    def call(env)
      if profile_requested?(env)
        profiler.profile_files_matching(file_matcher) do
          app.call(env)
        end
      else
        app.call(env)
      end
    end

    private

    def profile_requested?(env)
      env.has_key?('HTTP_PROFILE_AUTHORIZATION') &&
        env['HTTP_PROFILE_AUTHORIZATION'] == ENV['PROFILE_SECRET']
    end

    def reporter
      Pilfer::Logger.new($stdout, app_root: app_root)
    end

    def app_root
      ENV['PWD']
    end

    def file_matcher
      %r{^#{Regexp.escape(app_root)}(?!/vendor)}
    end
  end
end
