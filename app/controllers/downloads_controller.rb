# frozen_string_literal: true

# Serves one Blob: its raw bytes, or an on-the-fly zip wrapping a Blob Atlas
# could not identify. See docs/downloads.md.
class DownloadsController < ApplicationController
  include ProxyUnbuffered
  include RecordsImpressions
  include DerivativesHelper
  include ZipKit::RailsStreaming

  # Atlas's Classification.generic.name. Branch on the classification, never on
  # the "Zip File" download label: that label is shared with genuine archive
  # uploads, which are already zips and must stream as-is.
  GENERIC_CLASSIFICATION = 'File'

  before_action :authorize_show!
  before_action :authorize_derivative_read!, only: :show
  # Declared after the authz gates, so a blocked fetch is never counted, and
  # before the Live stream opens.
  before_action :record_download_impression, only: :show

  def show
    blob = AtlasRb::Blob.find(params[:id])
    wrap_in_zip? ? download_zipped(blob) : download_raw(blob)
  end

  private

    def download_raw(blob)
      response.headers['Content-Type'] = blob.mime_type
      response.headers['Content-Disposition'] =
        ActionDispatch::Http::ContentDisposition.format(disposition: 'attachment', filename: blob.filename)

      AtlasRb::Blob.content(params[:id]) { |chunk| response.stream.write(chunk) }
    ensure
      response.stream.close
    end

    # zip_kit_stream sets the type and disposition and, since ProxyUnbuffered
    # pulls in ActionController::Live, writes to and closes response.stream
    # itself — set no Content-* header and do not close the stream here.
    def download_zipped(blob)
      zip_kit_stream(filename: zip_filename(blob)) do |zip|
        BlobZipPacker.new(asset: @derivative_asset).pack(zip)
      end
    end

    def wrap_in_zip?
      @derivative_asset && @derivative_asset['classification'] == GENERIC_CLASSIFICATION
    end

    def zip_filename(blob)
      base = blob.filename.presence || blob.original_filename.presence || params[:id]
      "#{File.basename(base.to_s, '.*')}.zip"
    end

    # The per-Blob read gate, on top of the work-level authorize_show!. It lives
    # on the Work's assets payload, not on the standalone Blob, so the Work has
    # to be resolved first; the embargo needs its own call because the Blob's
    # permissions do not carry it. An unresolvable asset fails OPEN by design —
    # see docs/downloads.md before tightening that.
    def authorize_derivative_read!
      work_id = AtlasRb::Blob.work(params[:id], nuid: effective_user&.nuid)
      return if work_id.blank?

      @derivative_asset = AtlasRb::Work.assets(work_id, nuid: effective_user&.nuid)
                                       .find { |a| a['noid'] == params[:id] }
      return if @derivative_asset.nil?

      deny_if_unfinished_work!(work_id)
      deny_if_embargoed!(work_id)
      authorize! :read, derivative_tier_document(@derivative_asset)
    end
end
