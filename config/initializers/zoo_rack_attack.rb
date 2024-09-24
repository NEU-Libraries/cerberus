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

Rack::Attack.cache.store = ActiveSupport::Cache::RedisStore.new(:password => ENV["REDIS_PASSWD"], :host => 'nb9478.neu.edu', :port => 6379, :timeout => 10)

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

Rack::Attack.safelist("mark any devise user safe") do |request|
  !request.session["warden.user.user.key"].blank?
end

Rack::Attack.blocklist("Huawei datacenter") do |req|
  !req.remote_ip.blank? && `host #{req.remote_ip}`.include?("compute.hwclouds")
end

Rack::Attack.blocklist('Siteimprove') do |req|
  !req.user_agent.blank? && req.user_agent.downcase.include?("Siteimprove".downcase)
end

Rack::Attack.blocklist('MegaIndex') do |req|
  !req.user_agent.blank? && req.user_agent.downcase.include?("MegaIndex".downcase)
end

Rack::Attack.blocklist('Python') do |req|
  !req.user_agent.blank? && req.user_agent.downcase.include?("Python".downcase)
end

Rack::Attack.blocklist('sqlmap') do |req|
  !req.user_agent.blank? && req.user_agent.downcase.include?("sqlmap".downcase)
end

Rack::Attack.blocklist('turnitinbot') do |req|
  !req.user_agent.blank? && req.user_agent.downcase.include?("turnitinbot".downcase)
end

Rack::Attack.blocklist('Amazonbot') do |req|
  !req.user_agent.blank? && req.user_agent.downcase.include?("Amazonbot".downcase)
end

Rack::Attack.blocklist('AsyncHttpClient') do |req|
  !req.user_agent.blank? && req.user_agent.downcase.include?("Custom-AsyncHttpClient".downcase)
end

Rack::Attack.blocklist("Amazon") do |req|
  !req.remote_ip.blank? && `host #{req.remote_ip}`.include?("amazon")
end

Rack::Attack.throttle("CN Scrapers", limit: 1, period: 10) do |request|
  result = false
  if !request.env["HTTP_ACCEPT_LANGUAGE"].blank?
    raw_langs = request.env["HTTP_ACCEPT_LANGUAGE"]
    langs = raw_langs.to_s.split(",").map do |lang|
      l, q = lang.split(";q=")
      [l, (q || '1').to_f]
    end
    langs.each do |l|
      if l[0].downcase == "zh-cn"
        result = true
        end
      end
    end
  result
end

# Block attacks from IPs in cache
# To add an IP: Rails.cache.write("block 1.2.3.4", true, expires_in: 2.days)
# To remove an IP: Rails.cache.delete("block 1.2.3.4")
Rack::Attack.blocklist("block IP") do |req|
  Rails.cache.read("block #{req.remote_ip}")
end

# Bring back region throttle
Rack::Attack.throttle("requests by region", limit: 1, period: 10) do |request|
  `geoiplookup #{request.remote_ip} | awk -F', ' '{print $2}'`.strip == "China"
end

# Throttle attempts for a given octet to 3 reqs/10 seconds
Rack::Attack.throttle('load shedding', limit: 3, period: 10) do |req|
  # if cpu usage is approaching 4 on the 5 min avg...
  if `cut -d ' ' -f2 /proc/loadavg`.strip.to_f > 3
    if !req.remote_ip.blank?
      if `cut -d ' ' -f2 /proc/loadavg`.strip.to_f > 3.75
        # everyone out of the boat, no exceptions
        # log to file
        File.write("#{Rails.root}/log/heavy_load_shedding.log", "#{req.remote_ip} - #{req.path} - #{Time.now}" + "\n", mode: 'a')
        # ip address first octect discriminator
        req.remote_ip.split(".").first
      else
        # if url isnt frontpage, login related, assets, thumbs, API, throttle static response, or wowza...
        if (req.path != "/" &&
            !(req.path.include? "/users/") &&
            !(req.path.include? "/assets/") &&
            !(req.path.include? "thumbnail_") &&
            !(req.path.include? "/wowza/") &&
            !(req.path.include? "/429") &&
            !(req.path.include? "/api/"))

          host_result = `host #{req.remote_ip}`.strip

          if !(["lightspeed", "res.spectrum", "rcncustomer", "comcast", "fios.verizon"].any? { |x| host_result.include? x })
            # log to file
            File.write("#{Rails.root}/log/load_shedding.log", "#{req.remote_ip} - #{host_result} - #{req.path} - #{Time.now}" + "\n", mode: 'a')

            # ip address first octect discriminator
            req.remote_ip.split(".").first
          end
        end
      end
    end
  end
end

Rack::Attack.throttled_response = lambda do |env|
  html = ActionView::Base.new.render(file: 'public/429.html')
  [503, {'Content-Type' => 'text/html'}, [html]]
end
