# frozen_string_literal: true

# Mints the credentials the gated Cantaloupe host's authorization delegate
# validates: a size-bound signed URL for one-shot downloads, and a per-image
# signed identifier for interactive deep-zoom (whose tile URLs the viewer
# generates itself, so they cannot be signed individually — but they all share
# the image's identifier, so a token embedded there rides along on every one).
#
# All are HMAC-SHA256 over the shared secret in
# config.x.cerberus.iiif_signing_secret. The signed URL's message is the
# request PATH — which includes the IIIF size segment — plus the expiry, so a
# recipient cannot edit the size (e.g. `pct:50` → `max`) without breaking the
# signature. The identifier token's message is the bare image identifier plus
# the expiry: it authorizes every derived request for that one image (info.json
# + all tiles) until it expires, and — being carried in the URL — needs no
# cookie or credentialed CORS, so it works with IIIF's mandated cross-origin
# ACAO:*. The Cantaloupe delegate recomputes each exactly this way — keep the
# message formats here and in the delegate in lock-step.
module IiifSigner
  DOWNLOAD_TTL   = 5.minutes
  IDENTIFIER_TTL = 1.day

  class << self
    # @param url [String] a gated IIIF image URL (a Delegate's `uri`).
    # @return [String] the URL with `?exp=&sig=` appended.
    def sign_url(url, ttl: DOWNLOAD_TTL)
      exp = ttl.from_now.to_i
      sig = hmac("#{URI.parse(url).path}|#{exp}")
      "#{url}?exp=#{exp}&sig=#{sig}"
    end

    # Embeds a time-boxed token in the IIIF identifier itself, so it survives
    # into every tile URL OpenSeadragon derives from the image service base.
    #
    # The expiry is quantized to a `ttl`-sized window aligned to the epoch, so
    # every view within that window mints a byte-identical identifier — and thus
    # a stable Cantaloupe derivative-cache key. A fresh wall-clock `exp` per call
    # would give each page load a unique identifier, defeating that cache and
    # re-decoding every tile cold on every reload. Rounding up to the window
    # *after* next keeps the token valid for [ttl, 2*ttl), so one minted anywhere
    # in a window always has at least `ttl` left and tiles never 403 mid-view
    # near a boundary. The delegate reads whatever `exp` it is handed, so its
    # HMAC message ("<identifier>|<exp>") is unchanged.
    #
    # @param url [String] a gated IIIF image base (`…/iiif/3/gated-<uuid>.jp2`).
    # @return [String] the base with the identifier rewritten to
    #   `<exp>~<sig>~gated-<uuid>.jp2` (`~` avoids Cantaloupe's `;` meta-delimiter
    #   and keeps the identifier slash-free).
    def sign_identifier(url, ttl: IDENTIFIER_TTL)
      uri = URI.parse(url)
      identifier = File.basename(uri.path)
      window = ttl.to_i
      exp = ((Time.now.to_i / window) + 2) * window
      sig = hmac("#{identifier}|#{exp}")
      uri.path = "#{File.dirname(uri.path)}/#{exp}~#{sig}~#{identifier}"
      uri.to_s
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
