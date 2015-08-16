#!/usr/bin/ruby

require 'open-uri'
require 'set'
require 'digest'

names = Set.new

url = "bundler-api-staging.herokuapp.com"
#url = "localhost:9292"
open("http://#{url}/versions").readlines.reverse_each do |line|
  name, *_, sum = line.split(' ')
  next unless names.add?(name)
  info_sum = Digest::MD5.hexdigest open("http://#{url}/info/#{name}").read
 unless sum == info_sum
   puts name
   puts info_sum
   puts sum
 end
end
