# frozen_string_literal: true

require 'open3'
require 'json'

# Probes an A/V file's codecs to enforce the streaming safe-codec set at deposit.
# A deliberately thin seam: the deposit gate and specs stub this one class.
# `.available?` lets callers degrade on images built before ffmpeg was added.
#
# Safe set (the universal browser intersection, matching what v1 streamed):
# H.264 8-bit 4:2:0 video and/or AAC/MP3 audio. The CONTAINER is not checked
# here — a wrong container (e.g. H.264 in .mov) is remuxed by MediaRenditionJob,
# never rejected. Only the codec is a hard gate.
class Ffprobe
  SAFE_VIDEO_CODEC   = 'h264'
  SAFE_VIDEO_PIX_FMT = 'yuv420p' # 8-bit 4:2:0; 10-bit/4:2:2/4:4:4 carry other pix_fmts
  SAFE_AUDIO_CODECS  = %w[aac mp3].freeze
  TIMEOUT            = '30s'

  def self.available?
    system('which', 'ffprobe', out: File::NULL, err: File::NULL)
  end

  # @return [Array<Hash>] the file's stream descriptors (empty on any failure).
  def self.streams(path)
    out, _err, status = Open3.capture3(
      'timeout', TIMEOUT, 'ffprobe', '-v', 'error',
      '-show_streams', '-print_format', 'json', path.to_s
    )
    return [] unless status.success?

    JSON.parse(out).fetch('streams', [])
  rescue JSON::ParserError
    []
  end

  # @return [Boolean] true iff every real media stream is browser-universal.
  def self.safe?(path)
    video, audio = media_streams(streams(path))
    return false if video.empty? && audio.empty?

    (video + audio).all? { |stream| safe_stream?(stream) }
  end

  # Partition into real video (cover-art excluded) and audio streams.
  def self.media_streams(descriptors)
    video = descriptors.select { |s| video_stream?(s) }
    audio = descriptors.select { |s| s['codec_type'] == 'audio' }
    [video, audio]
  end

  def self.safe_stream?(stream)
    stream['codec_type'] == 'video' ? safe_video?(stream) : safe_audio?(stream)
  end

  # A real video stream — excludes cover-art / attached-picture streams
  # (e.g. mjpeg album art in an MP3), which mustn't flunk the gate.
  def self.video_stream?(stream)
    stream['codec_type'] == 'video' && stream.dig('disposition', 'attached_pic').to_i.zero?
  end

  def self.safe_video?(stream)
    stream['codec_name'] == SAFE_VIDEO_CODEC && stream['pix_fmt'] == SAFE_VIDEO_PIX_FMT
  end

  def self.safe_audio?(stream)
    SAFE_AUDIO_CODECS.include?(stream['codec_name'])
  end
end
