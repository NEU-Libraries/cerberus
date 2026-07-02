# frozen_string_literal: true

# Mints the credentials the gated Cantaloupe host's authorization delegate
# validates: a size-bound signed URL for one-shot downloads, and a time-boxed
# grant cookie for interactive deep-zoom (whose tile URLs the viewer generates
# itself, so they cannot be signed individually).
#
# Both are HMAC-SHA256 over the shared secret in
# config.x.cerberus.iiif_signing_secret. The signed URL's message is the
# request PATH — which includes the IIIF size segment — plus the expiry, so a
# recipient cannot edit the size (e.g. `pct:50` → `max`) without breaking the
# signature. The cookie is a bare time-boxed pass, safe under the
# service ⊆ large ⊆ … monotonicity constraint plus unguessable identifiers.
# The Cantaloupe delegate recomputes both exactly this way — keep the message
# formats here and in the delegate in lock-step.
module IiifSigner
  DOWNLOAD_TTL = 5.minutes
  COOKIE_TTL   = 1.hour

  class << self
    # @param url [String] a gated IIIF image URL (a Delegate's `uri`).
    # @return [String] the URL with `?exp=&sig=` appended.
    def sign_url(url, ttl: DOWNLOAD_TTL)
      exp = ttl.from_now.to_i
      sig = hmac("#{URI.parse(url).path}|#{exp}")
      "#{url}?exp=#{exp}&sig=#{sig}"
    end

    # @return [String] the grant-cookie value, "<exp>|<hmac>".
    def grant_cookie(ttl: COOKIE_TTL)
      exp = ttl.from_now.to_i
      "#{exp}|#{hmac("grant|#{exp}")}"
    end

    private

      def hmac(message)
        OpenSSL::HMAC.hexdigest('SHA256', secret, message)
      end

      def secret
        Rails.application.config.x.cerberus.iiif_signing_secret.presence ||
          raise(ArgumentError, 'CERBERUS_IIIF_SIGNING_SECRET is not configured')
      end
  end
end
