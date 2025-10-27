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
  def host_lookup
    @host_lookup ||= `timeout -s 9 -k 1 6 host -p 5053 #{remote_ip} 127.0.0.1`
  end

  def remote_ip
    @remote_ip ||= (env['action_dispatch.remote_ip'] || env['HTTP_X_FORWARDED_FOR'] || ip).to_s
  end

  def fingerprint
    @fingerprint ||= Base64.strict_encode64("#{env["HTTP_ACCEPT"]} | #{env["HTTP_ACCEPT_ENCODING"]} | #{env["HTTP_ACCEPT_LANGUAGE"]} | #{env["HTTP_COOKIE"]}")
  end

  def reverse_ip
    @reverse_ip ||= IPAddr.new(remote_ip).send("_reverse")
  end

  def asn
    @asn ||= `timeout -s 9 -k 1 6 dig +short #{reverse_ip}.origin.asn.cymru.com TXT | head -n 1 | tr -d \\" | awk '{print $1;}'`.strip
  end

  def region
    @region ||= `geoiplookup #{remote_ip} | awk -F', ' '{print $2}'`.strip
  end

  def original_method
    @original_method ||= env["rack.methodoverride.original_method"] || env['REQUEST_METHOD']
  end
end

Rack::Attack.cache.store = ActiveSupport::Cache::RedisStore.new(:password => ENV["REDIS_PASSWD"], :host => 'nb9667.neu.edu', :port => 6379, :timeout => 10)

Rack::Attack.safelist("passenger localhost prestart") do |req|
  !req.remote_ip.blank? && (req.remote_ip.strip == "127.0.0.1")
end

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

Rack::Attack.safelist("Wake Forest") do |req|
  !req.asn.blank? && req.asn == "40245"
end

Rack::Attack.safelist("Bielefeld University Library") do |req|
  !req.asn.blank? && req.asn == "680"
end

Rack::Attack.safelist("University of Cape Town") do |req|
  !req.asn.blank? && req.asn == "36982"
end

Rack::Attack.safelist("BPL") do |req|
  !req.asn.blank? && req.asn == "21949"
end

# NIEC
Rack::Attack.safelist("NIEC") do |req|
  !req.remote_ip.blank? && (req.remote_ip.strip == "162.215.121.62")
end

Rack::Attack.safelist("robots txt") do |req|
  req.fullpath.end_with?("robots.txt")
end

Rack::Attack.safelist("logging in") do |req|
  req.fullpath.include?("/users/")
end

Rack::Attack.blocklist("Bot Wave") do |req|
  req.referrer.blank? && req.env["HTTP_COOKIE"].blank? && (req.env["HTTP_ACCEPT"] == "*/*") && (req.user_agent.blank? || !req.user_agent.downcase.include?("bot".downcase))
end

Rack::Attack.blocklist("Peerdist") do |req|
  !req.env["HTTP_ACCEPT_ENCODING"].blank? && req.env["HTTP_ACCEPT_ENCODING"].downcase.include?("peerdist")
end

Rack::Attack.blocklist("Alibaba datacenter") do |req|
  !req.asn.blank? && req.asn == "45102"
end

Rack::Attack.blocklist("Google Cloud") do |req|
  if (req.user_agent.blank?) || (!req.user_agent.blank? && !req.user_agent.downcase.include?("bot".downcase))
    !req.asn.blank? && req.asn == "396982"
  end
end

Rack::Attack.blocklist("Digital Ocean") do |req|
  !req.asn.blank? && req.asn == "14061"
end

Rack::Attack.blocklist("Oracle") do |req|
  !req.asn.blank? && req.asn == "31898"
end

# Rack::Attack.blocklist("Azure") do |req|
#   !req.asn.blank? && req.asn == "8075"
# end

Rack::Attack.blocklist("Yandex") do |req|
  !req.asn.blank? && req.asn == "13238"
end

Rack::Attack.blocklist("BytePlus") do |req|
  !req.asn.blank? && req.asn == "150436"
end

Rack::Attack.blocklist("Zenlayer") do |req|
  !req.asn.blank? && req.asn == "21859"
end

Rack::Attack.blocklist("Viet") do |req|
  !req.asn.blank? && req.asn == "45899"
end

Rack::Attack.blocklist("Huawei ASN") do |req|
  !req.asn.blank? && ["136907", "55990", "151610"].include?(req.asn)
end

Rack::Attack.blocklist("zh-CN head bot") do |req|
  !req.asn.blank? && ["54994", "18004"].include?(req.asn)
end

Rack::Attack.blocklist("PDF Bots") do |req|
  !req.asn.blank? && ["207990", "263740", "52393", "9009", "36352", "401152", "203020", "20473"].include?(req.asn)
end

Rack::Attack.blocklist("Chiron") do |req|
  !req.asn.blank? && req.asn == "22773"
end

Rack::Attack.blocklist("Huawei datacenter") do |req|
  req.host_lookup.include?("compute.hwclouds")
end

Rack::Attack.blocklist("qwant") do |req|
  req.host_lookup.include?("qwant")
end

Rack::Attack.blocklist("Brazil wave") do |req|
  if (req.user_agent.blank?) || (!req.user_agent.blank? && !req.user_agent.downcase.include?("bot".downcase))
    (req.env["HTTP_ACCEPT_LANGUAGE"].blank?) && (req.region == "Brazil" || req.region.blank?)
  end
end

Rack::Attack.blocklist("Vietnam wave") do |req|
  if (req.user_agent.blank?) || (!req.user_agent.blank? && !req.user_agent.downcase.include?("bot".downcase))
    (req.env["HTTP_ACCEPT_LANGUAGE"].blank?) && (req.region == "Vietnam" || req.region.blank?)
  end
end

Rack::Attack.blocklist("Argentina wave") do |req|
  if (req.user_agent.blank?) || (!req.user_agent.blank? && !req.user_agent.downcase.include?("bot".downcase))
    (req.env["HTTP_ACCEPT_LANGUAGE"].blank?) && (req.region == "Argentina" || req.region.blank?)
  end
end

Rack::Attack.blocklist("Mexico wave") do |req|
  if (req.user_agent.blank?) || (!req.user_agent.blank? && !req.user_agent.downcase.include?("bot".downcase))
    (req.env["HTTP_ACCEPT_LANGUAGE"].blank?) && (req.region == "Mexico" || req.region.blank?)
  end
end

Rack::Attack.blocklist("Agent Liers") do |request|
  request.env["HTTP_ACCEPT"].blank? && request.env["HTTP_ACCEPT_LANGUAGE"].blank? && request.env["HTTP_COOKIE"].blank? && (request.user_agent.blank? || !request.user_agent.downcase.include?("bot".downcase))
end

Rack::Attack.blocklist("lang print") do |req|
  if (!req.user_agent.blank? && !req.user_agent.downcase.include?("bot".downcase))
    (req.env["HTTP_ACCEPT_LANGUAGE"].blank?) && (req.fingerprint == "Ki8qIHwgZ3ppcCwgZGVmbGF0ZSwgYnIgfCAgfCA=")
  end
end

Rack::Attack.blocklist('One hit wonders') do |req|
  req.referrer.blank? && req.env["HTTP_COOKIE"].blank? && (req.env["HTTP_ACCEPT_LANGUAGE"] == "en") && ((req.fullpath.include? "f%5B") || (req.region != "United States"))
end

Rack::Attack.blocklist('sec fetch extended') do |req|
  if (!req.user_agent.blank? && !req.user_agent.downcase.include?("bot".downcase))
    req.env["HTTP_SEC_FETCH_SITE"].blank? && req.referrer.blank? && (req.region != "United States")
  end
end

Rack::Attack.blocklist('Yandex UA') do |req|
  !req.user_agent.blank? && req.user_agent.downcase.include?("Yandex".downcase)
end

Rack::Attack.blocklist('ImagesiftBot') do |req|
  !req.user_agent.blank? && req.user_agent.downcase.include?("ImagesiftBot".downcase)
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
  req.host_lookup.include?("amazon")
end

Rack::Attack.blocklist("Hetzner") do |req|
  req.host_lookup.include?("clients.your-server.de")
end

Rack::Attack.blocklist('openai') do |req|
  !req.user_agent.blank? && req.user_agent.downcase.include?("openai".downcase)
end

Rack::Attack.blocklist("progressive throttle to block") do |req|
  if (!req.user_agent.blank? && !req.user_agent.downcase.include?("bot".downcase) && req.env["HTTP_SEC_FETCH_SITE"].blank?)
    if `cut -d ' ' -f2 /proc/loadavg`.strip.to_f > 1
      !req.env["HTTP_COOKIE"].blank? && req.env["HTTP_COOKIE"].include?("cerberus_throttled")
    end
  end
end

# Rack::Attack.blocklist("block shared banned cookie") do |req|
#   !req.env["HTTP_COOKIE"].blank? && req.env["HTTP_COOKIE"].include?("cerberus_blocked")
# end

Rack::Attack.blocklist("CN Azure") do |req|
  if !req.asn.blank? && (req.asn == "8075")
    if !req.env["HTTP_ACCEPT_LANGUAGE"].blank?
      req.env["HTTP_ACCEPT_LANGUAGE"].include?("zh-CN")
    end
  end
end

Rack::Attack.blocklist("CN Block") do |req|
  if `cut -d ' ' -f1 /proc/loadavg`.strip.to_f > 1
    if !req.env["HTTP_ACCEPT_LANGUAGE"].blank?
      if (req.region != "United States")
        req.env["HTTP_ACCEPT_LANGUAGE"].include?("zh-CN")
      end
    end
  end
end

Rack::Attack.blocklist("blacklight") do |req|
  if (!req.user_agent.blank? && !req.user_agent.downcase.include?("bot".downcase))
    req.env["HTTP_SEC_FETCH_SITE"].blank? && (req.fullpath.include?("&f") || req.fullpath.include?("?f") || req.fullpath.include?("creat") || req.fullpath.include?("rss"))
  end
end

Rack::Attack.throttle("pdf scraper mini wave", limit: 1, period: 10) do |request|
  if request.referrer.blank? && request.env["HTTP_COOKIE"].blank?
    if request.user_agent.blank? || !request.user_agent.downcase.include?("bot".downcase)
      if request.fullpath.include?("fulltext.pdf")
        if request.env["HTTP_RANGE"].blank?
          "#{request.fullpath} #{request.fingerprint}"
        end
      end
    end
  end
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

# Safelist from IPs in cache
# To add an IP: Rails.cache.write("safelist 1.2.3.4", true, expires_in: 2.days)
# To remove an IP: Rails.cache.delete("safelist 1.2.3.4")
Rack::Attack.safelist("safelist IP") do |req|
  Rails.cache.read("safelist #{req.remote_ip}")
end

# Block attacks from IPs in cache
# To add an IP: Rails.cache.write("block 1.2.3.4", true, expires_in: 2.days)
# To remove an IP: Rails.cache.delete("block 1.2.3.4")
Rack::Attack.blocklist("block IP") do |req|
  Rails.cache.read("block #{req.remote_ip}")
end

# Block by ASN in cache
# To add an IP: Rails.cache.write("block asn 45102", true, expires_in: 2.days)
# To remove an IP: Rails.cache.delete("block asn 45102")
Rack::Attack.blocklist("block asn") do |req|
  Rails.cache.read("block asn #{req.asn}")
end

# Block by fingerprint in cache
# To add an IP: Rails.cache.write("block fingerprint ZZwgZ3ppcCB8ICB8IA==", true, expires_in: 2.days)
# To remove an IP: Rails.cache.delete("block fingerprint ZZwgZ3ppcCB8ICB8IA==")
Rack::Attack.blocklist("block fingerprint") do |req|
  Rails.cache.read("block fingerprint #{req.fingerprint}")
end

# Bring back region throttle
Rack::Attack.throttle("requests by region - china", limit: 1, period: 10) do |request|
  if `cut -d ' ' -f1 /proc/loadavg`.strip.to_f > 1
    request.region == "China"
  end
end

Rack::Attack.blocklist("china region block") do |req|
  if `cut -d ' ' -f1 /proc/loadavg`.strip.to_f > 2
    req.region == "China"
  end
end

Rack::Attack.throttle("requests for pdf", limit: 2, period: 1) do |request|
  if `cut -d ' ' -f1 /proc/loadavg`.strip.to_f > 2
    if request.user_agent.blank? || !request.user_agent.downcase.include?("bot".downcase)
      if request.fullpath.include?("fulltext.pdf")
        if request.env["HTTP_RANGE"].blank?
          request.fingerprint
        end
      end
    end
  end
end

Rack::Attack.throttle("likely bot", limit: 1, period: 10) do |req|
  if req.env["HTTP_ACCEPT_LANGUAGE"].blank? && !req.user_agent.blank? && !req.user_agent.downcase.include?("bot".downcase)
    if !(req.fullpath.include? "/api/") && !(req.fullpath.include? "/oai")
      # log to file
      File.write("#{Rails.root}/log/likely_bot.log", "#{req.remote_ip} - #{req.fingerprint} - #{req.user_agent} - #{Time.now}" + "\n", mode: 'a')

      req.fingerprint
    end
  end
end

# Throttle attempts for a given octet to 1 reqs/10 seconds
Rack::Attack.throttle('load shedding', limit: 1, period: 10) do |req|
  # if cpu usage is approaching 4 on the 5 min avg...
  if `cut -d ' ' -f2 /proc/loadavg`.strip.to_f > 2.75
    if !req.remote_ip.blank?
      if `cut -d ' ' -f2 /proc/loadavg`.strip.to_f > 3.5
        # everyone out of the boat, no exceptions
        # log to file
        File.write("#{Rails.root}/log/heavy_load_shedding.log", "#{req.remote_ip} - #{req.fingerprint} - #{req.path} - #{Time.now}" + "\n", mode: 'a')
        # switching to fingerprint for better effectiveness on deep IP pools at the higher cpu usage
        req.fingerprint
      else
        # if url isnt frontpage, login related, assets, thumbs, API, throttle static response, or wowza...
        if (req.fullpath != "/" &&
            !(req.fullpath.include? "/users/") &&
            !(req.fullpath.include? "/assets/") &&
            !(req.fullpath.include? "thumbnail_") &&
            !(req.fullpath.include? "/wowza/") &&
            !(req.fullpath.include? "/429") &&
            !(req.fullpath.include? "/api/"))

          # log to file
          File.write("#{Rails.root}/log/load_shedding.log", "#{req.remote_ip} - #{req.fingerprint} - #{req.path} - #{Time.now}" + "\n", mode: 'a')

          # ip address first octect discriminator
          req.remote_ip.split(".").first
        end
      end
    end
  end
end

THROTTLE_HTML = ActionView::Base.new.render(file: 'public/429.html')

Rack::Attack.throttled_response = lambda do |env|
  [503, {'Set-Cookie' => "_cerberus_app_session=#{Date.today.to_time.to_i}", 'Set-Cookie' => 'cerberus_throttled=true', 'Content-Type' => 'text/html', 'Cache-Control' => 'no-cache, no-store, max-age=0, must-revalidate', 'Pragma' => 'no-cache'}, [THROTTLE_HTML]]
end

Rack::Attack.blocklisted_response = lambda do |env|
  [403, {'Set-Cookie' => "_cerberus_app_session=#{Date.today.to_time.to_i}", 'Set-Cookie' => 'cerberus_blocked=true', 'Content-Type' => 'text/plain', 'Cache-Control' => 'no-cache, no-store, max-age=0, must-revalidate', 'Pragma' => 'no-cache'}, ["Forbidden\n"]]
end

# Track requests from a special user agent.
Rack::Attack.track("not_declared_bot") do |req|
  req.env["HTTP_COOKIE"].blank? && !req.user_agent.blank? && !req.user_agent.downcase.include?("bot".downcase) &&
            (req.fullpath != "/" &&
            !(req.fullpath.include? "/users/") &&
            !(req.fullpath.include? "/assets/") &&
            !(req.fullpath.include? "thumbnail_") &&
            !(req.fullpath.include? "/wowza/") &&
            !(req.fullpath.include? "/429") &&
            !(req.fullpath.include? "/api/"))
end

Rack::Attack.track("head sec fetch site none print") do |req|
  if (!req.user_agent.blank? && !req.user_agent.downcase.include?("bot".downcase))
    if (req.original_method.downcase == "head") && (!req.env["HTTP_SEC_FETCH_SITE"].blank? && req.env["HTTP_SEC_FETCH_SITE"] == "none") && (req.fingerprint == "dGV4dC9odG1sLGFwcGxpY2F0aW9uL3hodG1sK3htbCxhcHBsaWNhdGlvbi94bWw7cT0wLjksKi8qO3E9MC44IHwgZ3ppcCwgZGVmbGF0ZSwgYnIgfCBlbi1VUyxlbjtxPTAuOSB8IA==")
      Rails.cache.write("block #{req.remote_ip}", true)
    end
  end
end

# Track it using ActiveSupport::Notification
ActiveSupport::Notifications.subscribe("rack.attack") do |name, start, finish, request_id, req|
  if (req.env['rack.attack.match_type'] != :blocklist) && req.env['rack.attack.matched'] == "not_declared_bot" && req.env['rack.attack.match_type'] == :track
    File.write("#{Rails.root}/log/#{DateTime.now.strftime("%F")}-fingerprints.log", "#{req.env['HTTP_X_FORWARDED_FOR']} - #{req.ip} | #{req.fingerprint}" + "\n", mode: 'a')
  end

  if (req.env['rack.attack.match_type'] == :blocklist) && !req.env["HTTP_COOKIE"].blank?
    File.write("#{Rails.root}/log/#{DateTime.now.strftime("%F")}-cookies-and-blocked.log", "#{req.env['rack.attack.matched']} - #{req.ip} | #{req.fingerprint}" + "\n", mode: 'a')
  end

  # if req.env['rack.attack.matched'] == "blacklight"
  #   File.write("#{Rails.root}/log/#{DateTime.now.strftime("%F")}-sec_fetch_site.log", "#{req.ip} | #{req.fingerprint}" + "\n", mode: 'a')
  # end

  if req.env['rack.attack.matched'] == "pdf scraper mini wave"
    File.write("#{Rails.root}/log/#{DateTime.now.strftime("%F")}-pdf_mini_wave.log", "#{req.ip} | #{req.fingerprint}" + "\n", mode: 'a')
  end

  # googlebot
  if (req.env['rack.attack.match_type'] == :blocklist) && req.host_lookup.include?("googlebot")
    File.write("#{Rails.root}/log/#{DateTime.now.strftime("%F")}-google-bot.log", "#{req.env['rack.attack.matched']} - #{req.ip} | #{req.user_agent} | #{req.fingerprint}" + "\n", mode: 'a')
  end

  # log head requests
  if (req.env['rack.attack.match_type'] != :blocklist) && !req.original_method.blank? && (req.original_method.downcase == "head")
    File.write("#{Rails.root}/log/#{DateTime.now.strftime("%F")}-head-reqs.log", "#{req.ip} | #{req.user_agent} | #{req.env["HTTP_SEC_FETCH_SITE"]} | #{req.fingerprint}" + "\n", mode: 'a')
  end
end
