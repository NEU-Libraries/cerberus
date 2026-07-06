# frozen_string_literal: true

# Cantaloupe delegate for the DRS gated-derivative model. Serves `open-*`
# identifiers (thumbnails / preview — the display pipe) freely, and requires a
# credential for `gated-*` (S/M/L downloads + deep-zoom): either a signed URL
# (`?exp=&sig=`, HMAC over "<request-path>|<exp>" — Cerberus's
# IiifSigner.sign_url) or a grant cookie (`iiif_grant=<exp>|<hmac>`, HMAC over
# "grant|<exp>" — IiifSigner.grant_cookie). Keep these HMAC message formats in
# lock-step with app/services/iiif_signer.rb.
#
# The shared secret is CERBERUS_IIIF_SIGNING_SECRET; when it is unset the
# delegate no-ops (serves everything), so a stack without the secret is ungated
# — enforcement is opt-in by setting the secret on both this service and web.
require 'openssl'
require 'uri'

class CustomDelegate
  # Cantaloupe sets the per-request context via this accessor before calling any
  # delegate method (see the bundled delegates.rb.sample); without it the proxy
  # raises on `context=` and the delegate is skipped (fails open).
  attr_accessor :context

  SECRET = ENV['CERBERUS_IIIF_SIGNING_SECRET'].to_s

  # Runs before the source image is accessed. Return true to allow, or a hash
  # with a status_code to deny. Source resolution stays config-based
  # (FilesystemSource.BasicLookupStrategy), so no source() override is needed.
  def pre_authorize(_options = {})
    return true if SECRET.empty?                                   # enforcement off
    return true if context['identifier'].to_s.start_with?('open-') # display pipe
    return true if valid_signature? || valid_cookie?

    { 'status_code' => 403 }
  end

  def authorize(_options = {})
    true
  end

  # Cantaloupe invokes these optional hooks through its delegate proxy —
  # redactions/metadata while processing each image, and the extra_iiif*
  # variants when building an info.json response. With no method defined the
  # proxy raises NoMethodError, which it logs as an ERROR per request. We add
  # nothing to any of them, so return the same no-op defaults the bundled
  # delegates.rb.sample ships with.
  def redactions(_options = {})
    []
  end

  def metadata(_options = {})
    nil
  end

  def extra_iiif2_information_response_keys(_options = {})
    {}
  end

  def extra_iiif3_information_response_keys(_options = {})
    {}
  end

  private

    # Signed download URL: ?exp=<ts>&sig=<hmac>, hmac = HMAC(SECRET, "<path>|<exp>").
    # The path includes the IIIF size segment, so the size can't be edited up.
    def valid_signature?
      args = query_args
      return false if args['sig'].to_s.empty? || args['exp'].to_s.empty?
      return false if args['exp'].to_i < Time.now.to_i

      secure_compare(hmac("#{request_path}|#{args['exp']}"), args['sig'])
    end

    # Grant cookie: iiif_grant=<exp>|<hmac>, hmac = HMAC(SECRET, "grant|<exp>").
    def valid_cookie?
      exp, sig = (context['cookies'] || {})['iiif_grant'].to_s.split('|', 2)
      return false if exp.to_s.empty? || sig.to_s.empty? || exp.to_i < Time.now.to_i

      secure_compare(hmac("grant|#{exp}"), sig)
    end

    def hmac(message)
      OpenSSL::HMAC.hexdigest('SHA256', SECRET, message)
    end

    # Constant-time comparison — avoid a timing oracle on the signature.
    def secure_compare(expected, given)
      return false unless expected.bytesize == given.bytesize

      expected.bytes.zip(given.bytes).reduce(0) { |acc, (x, y)| acc | (x ^ y) }.zero?
    end

    # The signed path — request_uri is the public, client-facing URI whose path
    # Cerberus signed over (host-independent, so proxy host-rewrites don't matter).
    def request_path
      URI(context['request_uri'].to_s).path
    end

    # Cantaloupe strips non-IIIF query params (exp/sig) from request_uri but keeps
    # them in local_uri, so read the credential from there.
    def query_args
      URI.decode_www_form(URI(context['local_uri'].to_s).query.to_s).to_h
    rescue StandardError
      {}
    end
end
