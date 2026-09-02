# frozen_string_literal: true

# Mix into a controller to record append-only usage impressions via Rails
# callbacks, off-request in RecordImpressionJob. See docs/analytics.md.
#
# Wire-in — the download callback MUST be declared after authorize_show!, so
# only authorized downloads are recorded:
#   after_action  :record_view_impression,     only: :show  # Work/Collection/Community
#   before_action :record_download_impression, only: :show  # Downloads
module RecordsImpressions
  extend ActiveSupport::Concern

  private

    # A tombstone 410 and an authz 403 both render, and neither is a view.
    def record_view_impression
      return unless response.successful?

      record_impression(noid: params[:id], action: 'view')
    end

    def record_download_impression
      record_impression(blob_id: params[:id], action: 'download')
    end

    # A ranged request is a stream (seek/playback), a full request a download.
    def record_media_impression
      action = request.headers['Range'].present? ? 'stream' : 'download'
      record_impression(blob_id: params[:id], action:)
    end

    def record_impression(action:, noid: nil, blob_id: nil)
      RecordImpressionJob.perform_later(
        action: action, noid: noid, blob_id: blob_id,
        request_meta: {
          session_id: request.session.id&.to_s,
          ip_address: request.remote_ip,
          referrer:   request.referer.presence || 'direct',
          user_agent: request.user_agent
        }
      )
    end
end
