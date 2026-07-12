# frozen_string_literal: true

# Cantaloupe delegate for the DRS gated-derivative model. Serves `open-*`
# identifiers (thumbnails / preview — the display pipe) freely, and requires a
# credential for `gated-*`:
#   - one-shot downloads: a signed URL (`?exp=&sig=`, HMAC over
#     "<request-path>|<exp>" — IiifSigner.sign_url).
#   - interactive deep-zoom: a per-image token embedded in the identifier
#     (`<exp>~<sig>~gated-<uuid>.jp2`, HMAC over "<identifier>|<exp>" —
#     IiifSigner.sign_identifier). It rides into every tile URL the viewer
#     derives from the image-service base, so all of them authorize without a
#     cookie — which is what lets it work cross-origin under IIIF's mandated
#     ACAO:*. Under ScriptLookupStrategy, `filesystemsource_pathname` strips the
#     token back to the real `gated-<uuid>.jp2` before resolving.
# Keep these HMAC message formats in lock-step with app/services/iiif_signer.rb.
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
  # The image volume Cantaloupe reads (the compose `iiif` mount). Under
  # ScriptLookupStrategy the delegate owns resolution, so it joins names here.
  IMAGE_ROOT = '/imageroot'

  # Runs before the source image is accessed. Return true to allow, or a hash
  # with a status_code to deny.
  def pre_authorize(_options = {})
    return true if SECRET.empty?                                   # enforcement off
    return true if context['identifier'].to_s.start_with?('open-') # display pipe
    return true if valid_identifier_token?(context['identifier'].to_s) # deep-zoom
    return true if valid_signature?                                    # one-shot download

    { 'status_code' => 403 }
  end

  def authorize(_options = {})
    true
  end

  # ScriptLookupStrategy resolution: map the IIIF identifier to an absolute file
  # under IMAGE_ROOT, stripping a deep-zoom token if present. Admits only the
  # minted open-/gated- JP2 names (uuid-shaped), so a crafted identifier can't
  # traverse out of the image root. nil ⇒ Cantaloupe reports not-found.
  def filesystemsource_pathname(_options = {})
    _, _, real = parse_token(context['identifier'].to_s)
    name = real || context['identifier'].to_s
    return unless /\A(open|gated)-[0-9a-f-]+\.jp2\z/.match?(name)

    File.join(IMAGE_ROOT, name)
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

    # Deep-zoom token embedded in the identifier: <exp>~<sig>~gated-<uuid>.jp2,
    # sig = HMAC(SECRET, "gated-<uuid>.jp2|<exp>"). One token authorizes every
    # derived request for that one image (info.json + all tiles) until exp.
    def valid_identifier_token?(identifier)
      exp, sig, real = parse_token(identifier)
      return false if real.nil? || exp < Time.now.to_i

      secure_compare(hmac("#{real}|#{exp}"), sig)
    end

    # [exp_i, sig, real_identifier] for a tokenized gated identifier, else nils.
    # `~` separates the parts (avoids Cantaloupe's `;` meta-delimiter); the real
    # identifier keeps its own hyphens.
    def parse_token(identifier)
      m = /\A(\d+)~(\h{64})~(gated-[0-9a-f-]+\.jp2)\z/.match(identifier)
      m ? [m[1].to_i, m[2], m[3]] : [nil, nil, nil]
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
