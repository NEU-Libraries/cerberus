require 'ipaddr'

module Rack
  class Attack
    module StoreProxy
      class RedisStoreProxy < SimpleDelegator
        def self.handle?(store)
          true
        end
      end
    end
  end
end

class Rack::Attack::Request < ::Rack::Request
  def remote_ip
    @remote_ip ||= (env['action_dispatch.remote_ip'] || env['HTTP_X_FORWARDED_FOR'] || ip).to_s
  end
end

Rack::Attack.cache.store = ActiveSupport::Cache::RedisStore.new(:host => 'nb9478.neu.edu', :port => 6379)

Rack::Attack.safelist("129 range") do |request|
  IPAddr.new("129.10.0.0/16").include?(request.remote_ip)
end

Rack::Attack.safelist("155 range") do |request|
  IPAddr.new("155.33.0.0/16").include?(request.remote_ip)
end

Rack::Attack.safelist("10 range") do |request|
  IPAddr.new("10.0.0.0/8").include?(request.remote_ip)
end

Rack::Attack.safelist("mark any authenticated access safe") do |request|
  !request.env["HTTP_COOKIE"].blank? && request.env["HTTP_COOKIE"].include?("shibsession")
end

Rack::Attack.throttle("requests by region", limit: 5, period: 2) do |request|
  # request.ip
  `geoiplookup #{request.remote_ip} | awk -F', ' '{print $2}'`.strip == "China"
end

Rack::Attack.blocklist("Amazon") do |req|
  !req.remote_ip.blank? && `host #{req.remote_ip}`.include?("amazon")
end

# Block attacks from IPs in cache
# To add an IP: Rails.cache.write("block 1.2.3.4", true, expires_in: 2.days)
# To remove an IP: Rails.cache.delete("block 1.2.3.4")
Rack::Attack.blocklist("block IP") do |req|
  Rails.cache.read("block #{req.remote_ip}")
end

LOGGER = Logger.new("log/rack-attack.log")
ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, req|
  msg = [req.env['rack.attack.match_type'], req.remote_ip, req.request_method, req.fullpath, ('"' + req.user_agent.to_s + '"')].join(' ')
  if [:throttle, :blocklist].include? req.env['rack.attack.match_type']
    LOGGER.error(msg)
  end
end
