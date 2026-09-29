# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaRenditionJob do
  before do
    allow(MediaRemux).to receive(:available?).and_return(true)
    allow(AtlasRb::Work).to receive(:file_sets).and_return(
      [AtlasRb::Mash.new(assets: [AtlasRb::Mash.new(role: 'original_file', noid: 'b-1')])]
    )
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
    expect(IiifAssetsJob).to have_received(:perform_now).with('w1', '/u/x-poster.jpg', refresh: false)
  end

  describe 'on a replace or revert' do
    def asset(noid, name, mime)
      AtlasRb::Mash.new(role: 'original_file', noid: noid, original_filename: name, mime_type: mime)
    end

    before do
      allow(Marcel::MimeType).to receive(:for).and_return('video/quicktime')
      allow(MediaRemux).to receive(:poster).and_return('/u/talk-poster.jpg')
      allow(MediaRemux).to receive(:to_mp4).and_return('/u/talk.mp4')
      allow(AtlasRb::Blob).to receive(:update)
    end

    # Each replace passes a fresh key, so creating here added an MP4 per replace.
    it "updates the Work's existing MP4 instead of attaching another" do
      allow(AtlasRb::Work).to receive(:file_sets).and_return(
        [AtlasRb::Mash.new(assets: [asset('b-mov', 'talk.mov', 'video/quicktime')]),
         AtlasRb::Mash.new(assets: [asset('b-mp4', 'talk.mp4', 'video/mp4')])]
      )

      described_class.perform_now('w1', '/u/talk.mov', 'key2', refresh: true)

      expect(AtlasRb::Blob).to have_received(:update).with('b-mp4', '/u/talk.mp4', idempotency_key: 'key2')
      expect(AtlasRb::Blob).not_to have_received(:create)
    end

    it 'attaches an MP4 when the Work has none yet' do
      allow(AtlasRb::Work).to receive(:file_sets).and_return(
        [AtlasRb::Mash.new(assets: [asset('b-mov', 'talk.mov', 'video/quicktime')])]
      )

      described_class.perform_now('w1', '/u/talk.mov', 'key2', refresh: true)

      expect(AtlasRb::Blob).to have_received(:create)
      expect(AtlasRb::Blob).not_to have_received(:update)
    end
  end

  it 'passes a refresh through, so a replaced video gets a fresh poster' do
    allow(Marcel::MimeType).to receive(:for).and_return('video/mp4')
    allow(MediaRemux).to receive(:poster).and_return('/u/x-poster.jpg')

    described_class.perform_now('w1', '/u/x.mp4', 'key1', refresh: true)

    expect(IiifAssetsJob).to have_received(:perform_now).with('w1', '/u/x-poster.jpg', refresh: true)
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
