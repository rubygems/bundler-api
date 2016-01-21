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

def migrate_created_at(database_url)
  puts "migrating created_at"
  db = Sequel.connect database_url

  gem_info = BundlerApi::GemInfo.new(db)

  versions_with_nil_created_at = db[:rubygems]
    .select_append(:versions__id___version_id)
    .join(:versions, rubygem_id: :id)
    .where(created_at: nil, indexed: true)

  require 'open-uri'
  require 'json'
  by_name = Hash.new do |h, name|
    json = JSON.load open("https://rubygems.org/api/v1/versions/#{name}.json")
    h[name] = json
  end

  now = Time.now
  versions_with_nil_created_at.each do |entry|
    id, name, version = entry.fetch_values(:id, :name, :number)
    versions = by_name[name]
    created_at = versions.find { |v| v["number"] == version }["created_at"]
    created_at = created_at ? Time.parse(created_at) : now
    created_at = now if now < created_at
    db[:versions].where(id: entry[:version_id]).update(created_at: created_at)
  end
end

def migrate_prerelease(database_url)
  puts "migrating prerelease"
  db = Sequel.connect database_url
  pre_release_versions = db[:versions].where(number: /[a-zA-Z]/)
  pre_release_versions.update(prerelease: true)
  non_pre_release_versions = db[:versions].exclude(number: /[a-zA-Z]/)
  non_pre_release_versions.update(prerelease: false)
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
  migrate_created_at(database_url)
  migrate_prerelease(database_url)
ensure
  drop_database(temp_database_url)
end
