source "https://rubygems.org"
# source "https://bundler-api-staging.herokuapp.com"

ruby File.read(File.expand_path('../.ruby-version', __FILE__)).strip

git_source(:github) do |repo|
  repo = "#{repo}/#{repo}" unless repo.include?("/")
  "https://github.com/#{repo}.git"
end

gem 'appsignal', '0.11.6.beta.0'
gem 'librato-metrics'
gem 'lock-smith'
gem 'metriks-librato_metrics', github: 'indirect/metriks-librato_metrics'
gem 'metriks-middleware'
gem 'pg'
gem 'puma'
gem 'puma_worker_killer'
gem 'rack-timeout', '0.4.0.beta.1', github: 'indirect/rack-timeout'
gem 'rake'
gem 'memcached', github: 'arthurnn/memcached'
gem 'redis'
gem 'sequel'
gem 'sequel_pg', require: false
gem 'sinatra'
gem 'json'
gem 'compact_index'
gem 'newrelic_rpm'

group :development do
  gem 'pry-byebug'
end

group :test do
  gem 'artifice'
  gem 'rack-test'
  gem 'rspec-core'
  gem 'rspec-expectations'
  gem 'rspec-mocks'
end

group :development, :test do
  gem 'foreman'
  gem 'dotenv', require: false
  gem 'rubocop', require: false
end
