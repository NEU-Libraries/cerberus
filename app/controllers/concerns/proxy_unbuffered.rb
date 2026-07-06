# frozen_string_literal: true

# Mixed into controllers that stream a response body via ActionController::Live
# (binary downloads, streamed zips, metadata exports, ranged media).
#
# A Live response carries no Content-Length. Behind a buffering reverse proxy
# (nginx in staging/prod) the proxy accumulates the chunk-by-chunk body instead
# of passing it through, and on this deployment that buffering truncates the
# download — the client receives only what the proxy buffered before cutting the
# stream, with the proxy stamping that partial length as Content-Length. Emitting
# `X-Accel-Buffering: no` is the per-response equivalent of `proxy_buffering off`:
# nginx honors it regardless of the location's buffering config and streams the
# body straight through. Harmless on the direct-Puma dev path (no proxy reads it).
module ProxyUnbuffered
  extend ActiveSupport::Concern

  included do
    include ActionController::Live

    before_action :disable_proxy_response_buffering
  end

  private

    def disable_proxy_response_buffering
      response.headers['X-Accel-Buffering'] = 'no'
    end
end
