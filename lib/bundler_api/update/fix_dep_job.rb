require 'bundler_api/update/job'

class BundlerApi::FixDepJob < BundlerApi::Job
  def initialize(db, payload, counter = nil, mutex = nil, silent: false)
    super(db, payload, mutex, counter, fix_deps: true, silent: silent)
  end
end
