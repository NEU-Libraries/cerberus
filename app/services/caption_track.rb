# frozen_string_literal: true

# One WebVTT Blob, served as a video Work's single player <track>. A caption is
# discriminated by MIME TYPE, never by role: Atlas gives every content Blob the
# role `original_file`, video master included. See docs/metadata-text.md.
class CaptionTrack
  MIME = 'text/vtt'
  EXTENSION = '.vtt'

  LANGUAGE = 'en'
  LABEL = 'English'

  REFUSED = 'Captions must be a WebVTT (.vtt) file. Convert an .srt file before you upload it.'

  # The Work's caption Blob among its assets, or nil. The `uri` test excludes
  # Delegates — the image tiers — which are not content.
  def self.for(files)
    Array(files).find { |file| file[:uri].blank? && file.mime_type.to_s == MIME }
  end

  # Video only. Its own predicate rather than StreamingOnly.applicable?, which
  # tests the same thing today for an unrelated reason — not one rule.
  def self.applicable?(files)
    Array(files).any? { |file| file[:uri].blank? && file.mime_type.to_s.start_with?('video/') }
  end

  # The extension, never sniffed content: WebVTT is plain text, so a sniffer
  # reports text/plain for a perfectly good caption file.
  def self.accepted?(filename)
    File.extname(filename.to_s).downcase == EXTENSION
  end
end
