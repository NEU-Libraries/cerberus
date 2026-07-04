# frozen_string_literal: true

require 'open3'

# Container-only A/V operations via ffmpeg: a lossless remux to MP4 and a poster
# frame. Never re-encodes (`-c copy`) — codecs are already gated safe at deposit,
# so this is pure container shuffling. A thin seam: MediaRenditionJob and specs
# stub this class. `.available?` degrades gracefully on pre-ffmpeg images.
class MediaRemux
  # Browser-universal containers — these need no remux; serve the master.
  PLAYABLE_CONTAINER_MIMES = %w[video/mp4 audio/mpeg audio/mp4].freeze
  TIMEOUT = '300s'

  def self.available?
    system('which', 'ffmpeg', out: File::NULL, err: File::NULL)
  end

  def self.remux_needed?(mime_type)
    PLAYABLE_CONTAINER_MIMES.exclude?(mime_type)
  end

  # The browser-playable A/V Blob among a work's assets — a Blob (not a Delegate)
  # in a universal container (the master if already MP4/MP3, else the ingest MP4
  # rendition). nil until one exists. The work-show player reads this.
  def self.playable_file(files)
    files.find { |file| file[:uri].blank? && PLAYABLE_CONTAINER_MIMES.include?(file.mime_type.to_s) }
  end

  # Lossless container swap to MP4, moov atom at the front for instant Range
  # playback.
  def self.to_mp4(source_path, target_path)
    run('-i', source_path.to_s, '-c', 'copy', '-movflags', '+faststart', target_path.to_s)
    target_path
  end

  # A single still frame ~3s in, as the video poster (fed to the thumbnail
  # pipeline). Fast pre-input seek; ffmpeg clamps to the last frame for very
  # short clips.
  def self.poster(source_path, target_path)
    run('-ss', '3', '-i', source_path.to_s, '-frames:v', '1', '-q:v', '3', target_path.to_s)
    target_path
  end

  def self.run(*)
    _out, err, status = Open3.capture3(
      'timeout', '--kill-after=10s', TIMEOUT, 'ffmpeg', '-y', '-loglevel', 'error', *
    )
    raise "ffmpeg failed (#{status.exitstatus}): #{err}" unless status.success?
  end
end
