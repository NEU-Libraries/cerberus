# frozen_string_literal: true

# The work page's Downloads card, the version chip on a replaced file's row, and
# the File history card under them. See docs/downloads.md.
module DownloadsHelper
  # What a download row calls its file. A caption track's label names its
  # language, and other assets fall back from the label to their use.
  def download_label(file)
    return CaptionTrack.download_label(file) if CaptionTrack.caption?(file)

    file.label.presence || file[:use]
  end

  # Each replaced Blob's revisions, newest first, keyed by its noid. A failed
  # read arrives as nil and gives no chips and no card.
  def file_revisions_by_blob(file_revisions)
    Array(file_revisions).to_h { |entry| [entry['blob_id'], Array(entry['revisions'])] }
  end

  # The File history card's entries: each file the Downloads card shows that
  # has revisions, in the card's order. Renditions carry a `uri` and none.
  def file_history_entries(files, revisions_by_blob)
    Array(files).filter_map do |file|
      next if file[:uri].present?

      revisions = revisions_by_blob[file[:noid]]
      [file, revisions] if revisions.present?
    end
  end

  # A reader cares which day a file changed, not the minute, so the history
  # shows the date alone, in the app's time zone.
  def file_revision_date(created)
    time = Time.iso8601(created.to_s).in_time_zone
    tag.time(time.strftime('%-d %B %Y'), datetime: time.iso8601)
  rescue ArgumentError
    tag.span('date unknown', class: 'text-subtle')
  end
end
