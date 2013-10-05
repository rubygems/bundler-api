require 'sequel'

RSpec.configure do |config|
  config.before(:suite) do
    fail 'TEST_DATABASE_URL is required' unless ENV["TEST_DATABASE_URL"]

    # Drop and recreate the database
    Sequel.connect('postgres://localhost/postgres') do |db|
      db_name = URI.parse(ENV["TEST_DATABASE_URL"]).path[1..-1]
      db.run("DROP DATABASE IF EXISTS #{db_name.inspect}")
      db.run("CREATE DATABASE #{db_name.inspect}")
    end

    # TODO: Replace global with singleton
    $db = Sequel.connect(ENV["TEST_DATABASE_URL"])
    Sequel.extension :migration
    Sequel::Migrator.run($db, 'db/migrations')
  end

  config.around(:each) do |example|
    $db.transaction(:rollback => :always) { example.run }
    $db.disconnect
  end
end
