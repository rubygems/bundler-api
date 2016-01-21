#!/usr/bin/env ruby

lib = File.expand_path(File.join('..', '..', '..', 'lib'), __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'bundler/setup'
require 'bundler_api/env'
require 'sequel'
require 'compact_index'
require 'bundler_api/gem_info'

## helpers

def database_name(database_url)
  File.basename(database_url)
end

def get_temp_database_url
  database_url = ENV['DATABASE_URL']
  abort 'DATABASE_URL environment variable required' unless database_url
  database_url + Time.now.to_i.to_s
end

## main commands

def drop_database(database_url)
  puts 'Dropping database'
  puts `dropdb --if-exists #{database_name(database_url)}`
end

def create_database(database_url)
  puts 'Creating database'
  puts `createdb --no-password #{database_name(database_url)}`
end

def import(database_url, sql_file)
  puts "Importing #{sql_file} data"
  puts `psql -d #{database_name(database_url)} -c "CREATE EXTENSION hstore"`
  puts `psql -d #{database_name(database_url)} < #{sql_file}`
end

def migrate_checksums(temp_database_url, database_url)
  temp_db = Sequel.connect temp_database_url
  db = Sequel.connect database_url

  puts "migrating checksum"

  versions_with_nil_checksum = db[:rubygems]
    .join(:versions, rubygem_id: :id)
    .where(checksum: nil)

  versions_with_nil_checksum.each do |entry|
    checksum_entry = temp_db[:versions]
      .select_append(:versions__created_at___versions_created_at)
      .join(:rubygems, id: :rubygem_id)
      .where(name: entry[:name], number: entry[:number])
      .first
    if checksum_entry
      checksum = checksum_entry[:sha256]
      created_at = checksum_entry[:versions_created_at]
      db[:versions].where(id: entry[:id]).update(checksum: checksum, created_at: created_at)
    end
  end
end

def migrate_info_checksums(database_url)
  puts "migrating info_checksum"
  db = Sequel.connect database_url

  gem_info = BundlerApi::GemInfo.new(db)

  versions_with_nil_info_checksum = db[:rubygems]
    .select_append(:versions__id___version_id)
    .join(:versions, rubygem_id: :id)
    .where(info_checksum: nil)

  info_checksums = {} # table with info_checksum per gem name

  versions_with_nil_info_checksum.each do |entry|
    name = entry[:name]
    unless info_checksums[name]
      info_checksums[name] = Digest::MD5.hexdigest(gem_info.info(name))
    end
    db[:versions].where(id: entry[:version_id]).update(info_checksum: info_checksums[name])
  end
end

## main

sql_file = ARGV.first
temp_database_url = get_temp_database_url
database_url = ENV['DATABASE_URL']

drop_database(temp_database_url)
create_database(temp_database_url)
begin
  import(temp_database_url,sql_file)
  migrate_checksums(temp_database_url, database_url)
  migrate_info_checksums(database_url)
ensure
  drop_database(temp_database_url)
end
