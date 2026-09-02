# frozen_string_literal: true

# Mints the two credentials the gated Cantaloupe host's authorization delegate
# validates: a size-bound signed URL, and a signed identifier for deep-zoom.
# The URL's HMAC message is the request PATH plus the expiry, so the size cannot
# be edited up but the query string can be appended to freely; the identifier's
# is the bare identifier plus the expiry. The Cantaloupe delegate recomputes
# both exactly this way — keep the message formats in lock-step with it.
# See docs/downloads.md.
module IiifSigner
  DOWNLOAD_TTL   = 5.minutes
  IDENTIFIER_TTL = 1.day

  class << self
    def sign_url(url, ttl: DOWNLOAD_TTL)
      exp = ttl.from_now.to_i
      sig = hmac("#{URI.parse(url).path}|#{exp}")
      "#{url}?exp=#{exp}&sig=#{sig}"
    end

    # The expiry is QUANTIZED, not wall-clock: every view in a window must mint
    # a byte-identical identifier, or each page load gets a unique one and
    # Cantaloupe's derivative cache is defeated. Rounding up to the window
    # *after* next keeps a token valid for [ttl, 2*ttl), so tiles never 403
    # mid-view near a boundary. `~` avoids Cantaloupe's `;` meta-delimiter and
    # keeps the identifier slash-free.
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
