# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaRenditionJob do
  before do
    allow(MediaRemux).to receive(:available?).and_return(true)
    allow(AtlasRb::Work).to receive(:find).and_return(double('work', in_progress: false))
    allow(AtlasRb::Blob).to receive(:create)
    allow(IiifAssetsJob).to receive(:perform_now)
    allow(File).to receive(:exist?).and_return(true)
  end

  it 'remuxes a non-MP4 video master to an MP4 Blob and seeds the poster' do
    allow(Marcel::MimeType).to receive(:for).and_return('video/quicktime')
    allow(MediaRemux).to receive(:poster).and_return('/u/x-poster.jpg')
    allow(MediaRemux).to receive(:to_mp4).and_return('/u/x.mp4')

    described_class.perform_now('w1', '/u/x.mov', 'key1')

    expect(AtlasRb::Blob).to have_received(:create).with('w1', '/u/x.mp4', 'x.mp4', idempotency_key: 'key1')
    expect(IiifAssetsJob).to have_received(:perform_now).with('w1', '/u/x-poster.jpg')
  end

  it 'skips remux for an MP4 master but still seeds the poster' do
    allow(Marcel::MimeType).to receive(:for).and_return('video/mp4')
    allow(MediaRemux).to receive(:poster).and_return('/u/x-poster.jpg')

    described_class.perform_now('w1', '/u/x.mp4', 'key1')

    expect(AtlasRb::Blob).not_to have_received(:create)
    expect(IiifAssetsJob).to have_received(:perform_now)
  end

  it 'does no poster and no remux for an MP3 audio master' do
    allow(Marcel::MimeType).to receive(:for).and_return('audio/mpeg')

    described_class.perform_now('w1', '/u/x.mp3', 'key1')

    expect(IiifAssetsJob).not_to have_received(:perform_now)
    expect(AtlasRb::Blob).not_to have_received(:create)
  end

  it 'skips entirely when ffmpeg is unavailable' do
    allow(MediaRemux).to receive(:available?).and_return(false)

    described_class.perform_now('w1', '/u/x.mov', 'key1')

    expect(AtlasRb::Blob).not_to have_received(:create)
  end
end
