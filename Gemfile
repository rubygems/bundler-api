source "https://rubygems.org"

ruby "2.2.0"

gem 'appsignal', '0.11.6.beta.0'
gem 'librato-metrics'
gem 'lock-smith'
gem 'metriks-librato_metrics', github: 'arthurnn/metriks-librato_metrics', ref: 'da539de267831e5aadfe52f1bb26df84b040c0f0'
gem 'metriks-middleware'
gem 'pg'
gem 'puma'
gem 'rake'
gem 'dalli'
gem 'redis'
gem 'sequel'
gem 'sequel_pg', require: false
gem 'sinatra'

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
end
