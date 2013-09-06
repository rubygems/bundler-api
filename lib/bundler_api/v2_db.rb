require 'bundler_api'

class BundlerApi::V2DB
  def initialize(conn)
    @conn = conn
  end

  def names
    @conn[:rubygems].select(:name).order(:name).all.map {|r| r[:name] }
  end
end
