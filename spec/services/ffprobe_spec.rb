# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ffprobe do
  def stub_streams(streams)
    allow(described_class).to receive(:streams).and_return(streams)
  end

  describe '.safe?' do
    it 'accepts H.264 8-bit 4:2:0 video + AAC audio' do
      stub_streams([{ 'codec_type' => 'video', 'codec_name' => 'h264', 'pix_fmt' => 'yuv420p' },
                    { 'codec_type' => 'audio', 'codec_name' => 'aac' }])
      expect(described_class.safe?('/x.mov')).to be(true)
    end

    it 'accepts MP3 audio-only' do
      stub_streams([{ 'codec_type' => 'audio', 'codec_name' => 'mp3' }])
      expect(described_class.safe?('/x.mp3')).to be(true)
    end

    it 'rejects HEVC video' do
      stub_streams([{ 'codec_type' => 'video', 'codec_name' => 'hevc', 'pix_fmt' => 'yuv420p' }])
      expect(described_class.safe?('/x.mp4')).to be(false)
    end

    it 'rejects 10-bit H.264 (pix_fmt yuv420p10le)' do
      stub_streams([{ 'codec_type' => 'video', 'codec_name' => 'h264', 'pix_fmt' => 'yuv420p10le' }])
      expect(described_class.safe?('/x.mp4')).to be(false)
    end

    it 'rejects H.264 with a non-AAC/MP3 audio track' do
      stub_streams([{ 'codec_type' => 'video', 'codec_name' => 'h264', 'pix_fmt' => 'yuv420p' },
                    { 'codec_type' => 'audio', 'codec_name' => 'flac' }])
      expect(described_class.safe?('/x.mkv')).to be(false)
    end

    it 'ignores attached-picture (cover-art) video streams' do
      stub_streams([{ 'codec_type' => 'video', 'codec_name' => 'mjpeg', 'disposition' => { 'attached_pic' => 1 } },
                    { 'codec_type' => 'audio', 'codec_name' => 'mp3' }])
      expect(described_class.safe?('/x.mp3')).to be(true)
    end

    it 'rejects a file with no media streams' do
      stub_streams([])
      expect(described_class.safe?('/x.bin')).to be(false)
    end
  end
end
