require 'csv'
require 'ipaddr'

class AsnLookup
  DEFAULT_PATH = File.join('/etc/cerberus/', 'GeoLite2-ASN-Blocks-IPv4.csv').freeze

  SUSPECT_ORG_PATTERNS = %w[
    hosting colocation datacenter
    onecable zenlayer psychz contabo leaseweb hetzner vultr
    digitalocean linode scaleway netcup hostwinds m247 choopa quadranet
    hostroyale servermania server\ mania vividhosting vivid-hosting
    whitelabelcolo coloup zetservers purevoltage netminders
    globalhostingsolutions b2\ net\ solutions b2net
    code200 oxylabs brightdata bright\ data luminati iproyal soax geonode
    amazon azure alibaba tencent
    censys shodan onyphe binaryedge internet-measurement
    net3-ai contact\ consumers
    akamai\ connected\ cloud
    data\ centers data\ center
    ovh
  ].map(&:downcase).freeze

  class << self
    def load!(path = DEFAULT_PATH)
      unless File.exist?(path)
        Rails.logger.warn("[AsnLookup] file not found at #{path}; lookups will return [nil, nil]")
        @blocks = []
        @starts = []
        return
      end

      rows = []
      CSV.foreach(path, :headers => true) do |r|
        net = IPAddr.new(r['network'])
        rows << [
          net.to_range.first.to_i,
          net.to_range.last.to_i,
          r['autonomous_system_number'].to_s,
          r['autonomous_system_organization'].to_s
        ]
      end
      rows.sort_by! { |row| row[0] }
      @blocks = rows
      @starts = rows.map { |row| row[0] }
      Rails.logger.info("[AsnLookup] loaded #{@blocks.length} ASN blocks from #{path}")
      true
    rescue => e
      Rails.logger.error("[AsnLookup] load failed: #{e.class} #{e.message}")
      @blocks = []
      @starts = []
      false
    end

    def loaded?
      !@blocks.nil?
    end

    def lookup(ip)
      return [nil, nil] if ip.nil? || ip.to_s.empty?
      return [nil, nil] unless loaded? && !@blocks.empty?

      n = ip_to_int(ip)
      return [nil, nil] if n.nil?

      i = bsearch_index(n)
      return [nil, nil] if i.nil?

      row = @blocks[i]
      return [nil, nil] unless n >= row[0] && n <= row[1]
      [row[2], row[3]]
    end

    def asn(ip)
      lookup(ip)[0]
    end

    def org(ip)
      lookup(ip)[1]
    end

    def suspect_org?(ip)
      o = org(ip)
      return false if o.nil? || o.empty?
      lc = o.downcase
      SUSPECT_ORG_PATTERNS.any? { |pat| lc.include?(pat) }
    end

    private

    def ip_to_int(ip)
      IPAddr.new(ip.to_s).to_i
    rescue IPAddr::Error, ArgumentError
      nil
    end

    def bsearch_index(n)
      lo = 0
      hi = @starts.length - 1
      result = nil
      while lo <= hi
        mid = (lo + hi) / 2
        if @starts[mid] <= n
          result = mid
          lo = mid + 1
        else
          hi = mid - 1
        end
      end
      result
    end
  end
end
