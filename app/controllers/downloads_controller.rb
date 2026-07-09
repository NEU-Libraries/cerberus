# frozen_string_literal: true

class DownloadsController < ApplicationController
  include ProxyUnbuffered
  include RecordsImpressions
  include DerivativesHelper
  include ZipKit::RailsStreaming

  # Atlas's Classification.generic.name: the marker for a blob whose content it
  # could not identify. The discriminator is the classification, not the "Zip
  # File" download label — that label is shared with genuine archive uploads
  # (classification "Archive"), which are already zips and must stream as-is. So
  # only "File" is wrapped; "Archive" and every typed classification serve raw.
  GENERIC_CLASSIFICATION = 'File'

  before_action :authorize_show!
  before_action :authorize_derivative_read!, only: :show
  # After the authz gates, so only authorized downloads are recorded; runs
  # before the Live stream opens (the job resolves blob → Work off-request).
  before_action :record_download_impression, only: :show

  # A blob Atlas could not identify (classification "File") is wrapped in a zip
  # generated on the fly — a grounded, inert download — while every typed blob
  # (and real archives, already zips) streams its raw bytes as before.
  def show
    blob = AtlasRb::Blob.find(params[:id])
    wrap_in_zip? ? download_zipped(blob) : download_raw(blob)
  end

  private

    # Stream the true bytes under the blob's own type and download name.
    def download_raw(blob)
      response.headers['Content-Type'] = blob.mime_type
      response.headers['Content-Disposition'] =
        ActionDispatch::Http::ContentDisposition.format(disposition: 'attachment', filename: blob.filename)

      AtlasRb::Blob.content(params[:id]) { |chunk| response.stream.write(chunk) }
    ensure
      response.stream.close
    end

    # zip_kit_stream sets the application/zip type + attachment disposition and,
    # since ProxyUnbuffered pulls in ActionController::Live, writes to and closes
    # response.stream itself — so no manual Content-* headers or stream.close
    # here. An on-the-fly archive can't honor Range (served 200, no
    # Accept-Ranges), which is fine for these rare one-off opaque files.
    def download_zipped(blob)
      zip_kit_stream(filename: zip_filename(blob)) do |zip|
        BlobZipPacker.new(asset: @derivative_asset).pack(zip)
      end
    end

    # Reads the classification off the assets entry authorize_derivative_read!
    # already resolved — no extra Atlas round-trip. A nil asset (the gate's
    # fail-open cases) serves raw.
    def wrap_in_zip?
      @derivative_asset && @derivative_asset['classification'] == GENERIC_CLASSIFICATION
    end

    # `<base>.zip`, base from the blob's download name, else its noid. The inner
    # entry keeps its real extension via ZipEntryWriter#entry_filename; only the
    # outer archive is renamed.
    def zip_filename(blob)
      base = blob.filename.presence || blob.original_filename.presence || params[:id]
      "#{File.basename(base.to_s, '.*')}.zip"
    end

    # Beyond the work-level authorize_show!, a Blob can carry its own read gate —
    # a department reserving the master (or a non-image rendition) while access
    # copies stay public. That gate lives on the Work's assets payload, not on
    # the standalone Blob, so resolve the containing Work (the same lookup the
    # impression path uses) and authorize this Blob's entry against the standard
    # :read Ability. Declared before record_download_impression so a blocked
    # fetch is never counted. Fails open only when the asset can't be resolved:
    # the work-level gate already passed, and a blob absent from the assets list
    # is an edge case, not a gate to bypass. The resolved entry is memoized
    # (@derivative_asset) so show can branch zip-vs-raw off its classification
    # without a second assets fetch.
    def authorize_derivative_read!
      work_id = AtlasRb::Blob.work(params[:id], nuid: effective_user&.nuid)
      return if work_id.blank?

      @derivative_asset = AtlasRb::Work.assets(work_id, nuid: effective_user&.nuid)
                                       .find { |a| a['noid'] == params[:id] }
      return if @derivative_asset.nil?

      authorize! :read, derivative_tier_document(@derivative_asset)
    end
end
