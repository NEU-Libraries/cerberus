# frozen_string_literal: true

# The work page's Downloads card, and the version chip on a replaced file's row.
# See docs/downloads.md.
module DownloadsHelper
  # What a download row calls its file. A caption track's label names its
  # language, and other assets fall back from the label to their use.
  def download_label(file)
    return CaptionTrack.download_label(file) if CaptionTrack.caption?(file)

    file.label.presence || file[:use]
  end

  # Each replaced Blob's revisions, newest first, keyed by its noid. A failed
  # read arrives as nil and gives no chips.
  def file_revisions_by_blob(file_revisions)
    Array(file_revisions).to_h { |entry| [entry['blob_id'], Array(entry['revisions'])] }
  end

  # A reader cares which day a file changed, not the minute, so the chip's menu
  # shows the date alone, in the app's time zone.
  def file_revision_date(created)
    time = Time.iso8601(created.to_s).in_time_zone
    tag.time(time.strftime('%-d %B %Y'), datetime: time.iso8601)
  rescue ArgumentError
    tag.span('date unknown', class: 'text-subtle')
  end
end
