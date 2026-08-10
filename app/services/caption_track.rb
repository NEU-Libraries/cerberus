# frozen_string_literal: true

# The caption track of a video Work: one WebVTT Blob, served under the in-page
# player as the single <track>.
#
# One track, and it is labelled English, because that is the whole of what the
# repository can currently say. A Blob carries a mime type and a filename and
# nothing a <track> wants — Atlas has no field for a caption's language or its
# display label — so a second caption could be stored but never told apart from
# the first. The offer therefore matches what can be described, and a
# multi-language Work waits on Atlas growing somewhere to put the language.
#
# WebVTT only. A browser <track> parses no other format, and an SRT conversion is
# work this application does not do, so an .srt upload is refused at the form
# rather than stored as a file no player will read.
#
# A caption is discriminated by MIME TYPE, not by role. Atlas gives every content
# Blob the role `original_file`, the video master included, so role cannot answer
# "which of these is the captions" — see CaptionJob, which owes the same fact a
# guard.
class CaptionTrack
  MIME = 'text/vtt'
  EXTENSION = '.vtt'

  # The srclang/label pair every track carries, since nothing records the real
  # ones. English matches v1, which hardcoded exactly this.
  LANGUAGE = 'en'
  LABEL = 'English'

  REFUSED = 'Captions must be a WebVTT (.vtt) file. Convert an .srt file before you upload it.'

  # The Work's caption Blob among its assets, or nil.
  #
  # There is at most one, because the write path replaces the bytes of the Blob it
  # finds here rather than attaching a second (CaptionJob). Delegates — the image
  # tiers — carry a `uri` and are not content, the same test
  # MediaRemux.playable_file makes.
  #
  # @param files [Array] the Work's asset entries.
  # @return [AtlasRb::Mash, nil]
  def self.for(files)
    Array(files).find { |file| file[:uri].blank? && file.mime_type.to_s == MIME }
  end

  # Whether to offer the caption field for this Work at all: it has a video Blob.
  #
  # Video only, matching what v1 offered and what was asked for. A <track> would
  # work over the audio player too, so widening this is a decision rather than a
  # port, and it belongs to whoever wants transcripts on audio.
  #
  # Deliberately its own predicate rather than StreamingOnly.applicable?, which
  # tests the same thing today for an unrelated reason — two features that happen
  # to agree, not one rule.
  #
  # @param files [Array] the Work's asset entries.
  # @return [Boolean]
  def self.applicable?(files)
    Array(files).any? { |file| file[:uri].blank? && file.mime_type.to_s.start_with?('video/') }
  end

  # Whether an upload is one this feature accepts, by extension.
  #
  # The extension rather than sniffed content: WebVTT is plain text, so a sniffer
  # reports text/plain for a perfectly good caption file, and Atlas itself types
  # the stored Blob text/vtt off the name.
  #
  # @param filename [String, nil]
  # @return [Boolean]
  def self.accepted?(filename)
    File.extname(filename.to_s).downcase == EXTENSION
  end
end
