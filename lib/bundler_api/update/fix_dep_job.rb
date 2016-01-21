require 'bundler_api/update/job'

class BundlerApi::FixDepJob < BundlerApi::Job
  def initialize(db, payload, counter = nil, mutex = nil)
    super(db, payload, mutex, counter, fix_deps: true)
  end
end
