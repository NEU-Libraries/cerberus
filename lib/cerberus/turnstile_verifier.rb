require 'net/http'
require 'json'
require 'uri'

module Cerberus
  module TurnstileVerifier
    ENDPOINT = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify").freeze

    Result = Struct.new(:success?, :error_codes, :soft_fail)

    def self.verify(token, remoteip)
      http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
      http.use_ssl = true
      http.open_timeout = 3
      http.read_timeout = 5

      req = Net::HTTP::Post.new(ENDPOINT.request_uri)
      req.set_form_data(
        "secret"   => ENV["TURNSTILE_SECRET_KEY"],
        "response" => token,
        "remoteip" => remoteip
      )

      resp = http.request(req)

      if resp.is_a?(Net::HTTPSuccess)
        body = JSON.parse(resp.body) rescue {}
        Result.new(body["success"] == true, body["error-codes"] || [], false)
      else
        Rails.logger.warn("[turnstile] non-2xx from siteverify: #{resp.code}")
        Result.new(false, ["http_#{resp.code}"], true)
      end
    rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError => e
      Rails.logger.warn("[turnstile] net error: #{e.class}: #{e.message}")
      Result.new(false, ["net_error"], true)
    end
  end
end
