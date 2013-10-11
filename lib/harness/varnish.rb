require "harness/varnish/version"

require 'harness'

require 'uri'
require 'net/http'
require 'multi_json'

module Harness
  class VarnishGauge
    include Instrumentation

    BadResponseError = Class.new StandardError

    def initialize(url)
      @url = url
    end

    def log
      uri = URI.parse @url

      http = Net::HTTP.new uri.host, uri.port
      http.use_ssl = uri.scheme == 'https'

      request = Net::HTTP::Get.new uri.request_uri

      if uri.user || uri.password
        request.basic_auth uri.user, uri.password
      end

      response = http.request request

      if response.code.to_i != 200
        raise BadResponseError, "Server did not respond correctly! #{response.inspect}"
      end

      body = MultiJson.load response.body

      hits = body.fetch('cache_hit').fetch('value')
      misses = body.fetch('cache_miss').fetch('value')
      hit_rate = (hits.to_f / (hits + misses).to_f) * 100

      gauge 'varnish.hits', hits
      gauge 'varnish.misses', misses
      gauge 'varnish.hit_rate', hit_rate

      gauge 'varnish.cached', body.fetch('n_object').fetch('value')

      gauge 'varnish.connections', body.fetch('client_conn').fetch('value')
      gauge 'varnish.requests', body.fetch('client_req').fetch('value')

      header_bytes = body.fetch('s_hdrbytes').fetch('value')
      body_bytes = body.fetch('s_bodybytes').fetch('value')
      gauge 'varnish.bandwidth', header_bytes + body_bytes
    end
  end
end
