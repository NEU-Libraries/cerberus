# frozen_string_literal: true

# Mix into a controller to record append-only usage impressions via Rails
# callbacks. Fire-and-forget: the insert (and its dedup throttle) run off-request
# in RecordImpressionJob, so this is cheap and safe even immediately before an
# ActionController::Live stream begins.
#
# Wire-in:
#   after_action  :record_view_impression,     only: :show  # Work/Collection/Community
#   before_action :record_download_impression, only: :show  # Downloads (after authorize_show!)
module RecordsImpressions
  extend ActiveSupport::Concern

  private

    # Record a view only when the request actually rendered — a tombstone 410 or
    # an authz 403 is not a view.
    def record_view_impression
      return unless response.successful?

      record_impression(noid: params[:id], action: 'view')
    end

    # Declared after authorize_show!, so only authorized downloads are recorded.
    # The job resolves the containing Work's noid from the blob id.
    def record_download_impression
      record_impression(blob_id: params[:id], action: 'download')
    end

    # Enqueue an impression. Pass either a resolved noid (a view) or a blob_id
    # (a download — resolved to its Work in the job). The request-derived fields
    # are grouped so the job's signature stays small.
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
