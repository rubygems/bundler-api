require 'sequel'

RSpec.configure do |config|
  config.before(:suite) do
    db_url = ENV["TEST_DATABASE_URL"]
    fail 'TEST_DATABASE_URL is required' if db_url.nil? || db_url.empty?

    # Drop and recreate the database
    Sequel.connect(ENV["TEST_DATABASE_ADMIN_URL"]) do |db|
      db_name = URI.parse(ENV["TEST_DATABASE_URL"]).path[1..-1]
      db.run("DROP DATABASE IF EXISTS #{db_name.inspect}")
      db.run("CREATE DATABASE #{db_name.inspect}")
    end

    # TODO: Replace global with singleton
    $db = Sequel.connect(db_url)
    Sequel.extension :migration
    Sequel::Migrator.run($db, 'db/migrations')
  end

  config.around(:each) do |example|
    $db.transaction(:rollback => :always) { example.run }
    $db.disconnect
  end
end
