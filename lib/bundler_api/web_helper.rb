require 'bundler_api'
require 'open-uri'

class BundlerApi::WebHelper
  def get(url)
    open(url) { |io| io.read }
  end
end
