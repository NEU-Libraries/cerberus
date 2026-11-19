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
  # See docs/admin.md.
  class FileVersionsController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    include ProxyUnbuffered
    include StreamsBlob

    # An unknown version is Atlas's 404, which StreamsBlob renders as the
    # not-found page because no header is set before the first chunk.
    def content
      blob = require_resource!(AtlasRb::Blob.find(params[:id]))
      stream_blob_version(params[:id], params[:version_id]) { apply_download_headers(blob) }
    end

    private

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
