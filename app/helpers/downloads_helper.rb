# frozen_string_literal: true

# The work page's Downloads card and the File history card under it.
module DownloadsHelper
  # What a download row calls its file. A caption track's label names its
  # language, and other assets fall back from the label to their use.
  def download_label(file)
    return CaptionTrack.download_label(file) if CaptionTrack.caption?(file)

    file.label.presence || file[:use]
  end

  # Pairs each Blob in `files` with its revisions, newest first. Only the files
  # the Downloads card shows get a history, so a file withheld from the viewer
  # stays out of both cards. Renditions carry a `uri` and no revisions.
  def file_history_entries(files, file_revisions)
    by_blob = Array(file_revisions).to_h { |entry| [entry['blob_id'], Array(entry['revisions'])] }

    Array(files).filter_map do |file|
      next if file[:uri].present?

      revisions = by_blob[file[:noid]]
      [file, revisions] if revisions.present?
    end
  end
end
