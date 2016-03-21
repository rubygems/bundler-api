threads ENV.fetch('MIN_THREADS', 1), ENV.fetch('MAX_THREADS', 1)
port ENV['PORT'] if ENV['PORT']
workers ENV.fetch('WORKER_COUNT', 1)

require 'bundler_api/metriks'
BundlerApi::Metriks.start

require 'puma_worker_killer'
PumaWorkerKiller.enable_rolling_restart

on_worker_boot do |index|
  BundlerApi::Metriks.start(index)
end
