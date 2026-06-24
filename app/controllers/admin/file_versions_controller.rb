# frozen_string_literal: true

module Admin
  # Streams the bytes of a *prior* version of a Blob (the "download the superseded
  # file" half of the replace surface). The version-pinned twin of
  # DownloadsController#show — admin-gated via BaseController, and chunked through
  # ActionController::Live so a large superseded file is never buffered in memory.
  # Lives apart from FilesController so Live's stream semantics don't bleed onto
  # the finder/mutation actions.
  class FileVersionsController < BaseController
    include ActionController::Live

    def content
      apply_download_headers(AtlasRb::Blob.find(params[:id]))
      AtlasRb::Blob.version_content(params[:id], params[:version_id]) { |chunk| response.stream.write(chunk) }
    ensure
      response.stream.close
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
