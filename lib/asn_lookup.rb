require 'csv'
require 'set'

class AsnLookup
  DEFAULT_PATH = File.join('/etc/cerberus/', 'GeoLite2-ASN-Blocks-IPv4.csv').freeze

  SUSPECT_ORG_PATTERNS = %w[
    hosting colocation datacenter chiron
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
        Rails.logger.warn("[AsnLookup] file not found at #{path}; lookups will return nil/false")
        @asn_to_org = nil
        @suspect_asns = nil
        return false
      end

      asn_to_org = {}
      CSV.foreach(path, :headers => true) do |r|
        asn = r['autonomous_system_number'].to_s
        next if asn.empty? || asn_to_org.key?(asn)
        asn_to_org[asn] = r['autonomous_system_organization'].to_s
      end

      suspect_asns = Set.new
      asn_to_org.each do |asn, org|
        lc = org.downcase
        suspect_asns << asn if SUSPECT_ORG_PATTERNS.any? { |pat| lc.include?(pat) }
      end

      @asn_to_org = asn_to_org.freeze
      @suspect_asns = suspect_asns.freeze
      Rails.logger.info("[AsnLookup] loaded #{@asn_to_org.size} ASN->org entries (#{@suspect_asns.size} suspect) from #{path}")
      true
    rescue => e
      Rails.logger.error("[AsnLookup] load failed: #{e.class} #{e.message}")
      @asn_to_org = nil
      @suspect_asns = nil
      false
    end

    def loaded?
      !@asn_to_org.nil?
    end

    def org(asn)
      return nil unless loaded?
      @asn_to_org[asn.to_s]
    end

    def suspect_asn?(asn)
      return false unless loaded?
      @suspect_asns.include?(asn.to_s)
    end
  end
end
