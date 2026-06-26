# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaRemux do
  describe '.remux_needed?' do
    it 'is false for browser-universal containers' do
      expect(described_class.remux_needed?('video/mp4')).to be(false)
      expect(described_class.remux_needed?('audio/mpeg')).to be(false)
      expect(described_class.remux_needed?('audio/mp4')).to be(false)
    end

    it 'is true for other containers' do
      expect(described_class.remux_needed?('video/quicktime')).to be(true)
      expect(described_class.remux_needed?('video/x-matroska')).to be(true)
    end
  end

  describe '.to_mp4' do
    it 'shells out a lossless -c copy +faststart remux and returns the target' do
      allow(described_class).to receive(:run)
      expect(described_class.to_mp4('/in.mov', '/out.mp4')).to eq('/out.mp4')
      expect(described_class).to have_received(:run)
        .with('-i', '/in.mov', '-c', 'copy', '-movflags', '+faststart', '/out.mp4')
    end
  end

  describe '.poster' do
    it 'extracts a single frame and returns the target' do
      allow(described_class).to receive(:run)
      expect(described_class.poster('/in.mp4', '/out.jpg')).to eq('/out.jpg')
      expect(described_class).to have_received(:run)
        .with('-ss', '3', '-i', '/in.mp4', '-frames:v', '1', '-q:v', '3', '/out.jpg')
    end
  end
end
