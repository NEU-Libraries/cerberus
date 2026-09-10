# frozen_string_literal: true

module Admin
  # Streams the bytes of a *prior* version of a Blob (the "download the superseded
  # file" half of the replace surface). The version-pinned twin of
  # DownloadsController#show — chunked through ActionController::Live so a large
  # superseded file is never buffered in memory. Reachable by :admin and by the
  # devolved-admin tier (User#admin_delegate?), matching FilesController's gate —
  # this is the other half of the same "replace a file" surface. Lives apart from
  # FilesController so Live's stream semantics don't bleed onto the
  # finder/mutation actions.
  class FileVersionsController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    include ProxyUnbuffered

    # The version id is checked against the Blob's own history BEFORE any bytes
    # move. Atlas answers an unknown version with a 404 whose body the streaming
    # binding cannot raise on — chunks reach the client before the status is
    # known — so without this the error body arrives as the file's contents,
    # under a 200 and the download filename. A refusal has to happen up front or
    # not at all.
    def content
      blob = AtlasRb::Blob.find(params[:id])
      raise ResourceNotFound if blob.nil?
      raise ResourceNotFound unless known_version?(params[:id], params[:version_id])

      apply_download_headers(blob)
      stream_version
    ensure
      response.stream.close
    end

    private

      def stream_version
        result = AtlasRb::Blob.version_content(params[:id], params[:version_id]) do |chunk|
          response.stream.write(chunk)
        end
        log_stream_failure(result) unless (200..299).cover?(result[:status])
      end

      def known_version?(blob_noid, version_id)
        versions = AtlasRb::Blob.versions(blob_noid)
        Array(versions && versions['versions']).any? { |v| v['version_id'] == version_id }
      end

      # The response is already committed by the time this runs, so there is
      # nothing to render — the log is the only place the failure can surface.
      def log_stream_failure(result)
        Rails.logger.error(
          "FileVersionsController: Atlas answered #{result[:status]} streaming " \
          "#{params[:id]} #{params[:version_id]}; the download may be truncated or an error body"
        )
      end

      def apply_download_headers(blob)
        response.headers['Content-Type'] = blob.mime_type
        response.headers['Content-Disposition'] = ActionDispatch::Http::ContentDisposition.format(
          disposition: 'attachment', filename: versioned_filename(blob)
        )
      end

      # Suffix the version label onto the basename so concurrent downloads of
      # different versions don't collide: "report.pdf" → "report (v1).pdf".
      def versioned_filename(blob)
        name = blob.filename.to_s
        ext  = File.extname(name)
        base = ext.empty? ? name : name[0...-ext.length]
        "#{base} (#{params[:version_id]})#{ext}"
      end
  end
end
