# frozen_string_literal: true

class DownloadsController < ApplicationController
  include ProxyUnbuffered
  include RecordsImpressions
  include DerivativesHelper

  before_action :authorize_show!
  before_action :authorize_derivative_read!, only: :show
  # After the authz gates, so only authorized downloads are recorded; runs
  # before the Live stream opens (the job resolves blob → Work off-request).
  before_action :record_download_impression, only: :show

  def show
    blob = AtlasRb::Blob.find(params[:id])

    response.headers['Content-Type'] = blob.mime_type
    response.headers['Content-Disposition'] =
      ActionDispatch::Http::ContentDisposition.format(disposition: 'attachment', filename: blob.filename)

    AtlasRb::Blob.content(params[:id]) { |chunk| response.stream.write(chunk) }
  ensure
    response.stream.close
  end

  private

    # Beyond the work-level authorize_show!, a Blob can carry its own read gate —
    # a department reserving the master (or a non-image rendition) while access
    # copies stay public. That gate lives on the Work's assets payload, not on
    # the standalone Blob, so resolve the containing Work (the same lookup the
    # impression path uses) and authorize this Blob's entry against the standard
    # :read Ability. Declared before record_download_impression so a blocked
    # fetch is never counted. Fails open only when the asset can't be resolved:
    # the work-level gate already passed, and a blob absent from the assets list
    # is an edge case, not a gate to bypass.
    def authorize_derivative_read!
      work_id = AtlasRb::Blob.work(params[:id], nuid: effective_user&.nuid)
      return if work_id.blank?

      asset = AtlasRb::Work.assets(work_id, nuid: effective_user&.nuid)
                           .find { |a| a['noid'] == params[:id] }
      return if asset.nil?

      authorize! :read, derivative_tier_document(asset)
    end
end
