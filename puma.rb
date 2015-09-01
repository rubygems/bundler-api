threads ENV.fetch('MIN_THREADS', 1), ENV.fetch('MAX_THREADS', 1)
port ENV['PORT'] if ENV['PORT']
workers ENV.fetch('WORKER_COUNT', 1)

require 'bundler_api/metriks'
BundlerApi::Metriks.start

on_worker_boot do
  BundlerApi::Metriks.start
end
