# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'works/_av_player', type: :view do
  def render_player(mime:, preview:, downloadable: true, caption: nil)
    assign(:work, AtlasRb::Mash.new(preview: preview))
    render partial: 'works/av_player',
           locals:  { file:    AtlasRb::Mash.new(noid: 'b-1', mime_type: mime),
                      caption: caption, downloadable: downloadable }
  end

  let(:captions) { AtlasRb::Mash.new(noid: 'c-1', mime_type: 'text/vtt') }

  context 'audio with a poster' do
    before { render_player(mime: 'audio/mpeg', preview: 'https://iiif/x.jp2/full/500,/0/default.jpg') }

    it 'renders a <video> carrying the poster (no bare <audio>)' do
      expect(rendered).to have_css('video.av-player__media[poster="https://iiif/x.jp2/full/500,/0/default.jpg"]')
      expect(rendered).to have_no_css('audio')
    end

    it 'flags the audio-poster value on the controller element so audioPosterMode is enabled' do
      expect(rendered).to have_css('.av-player[data-av-player-audio-poster-value="true"]')
    end
  end

  context 'audio without a poster' do
    before { render_player(mime: 'audio/mpeg', preview: nil) }

    it 'falls back to a bare <audio> element' do
      expect(rendered).to have_css('audio.av-player__media')
      expect(rendered).to have_no_css('video')
    end
  end

  context 'video' do
    before { render_player(mime: 'video/mp4', preview: 'https://iiif/v.jp2/full/500,/0/default.jpg') }

    it 'renders a <video> with the poster and leaves audio-poster mode off' do
      expect(rendered).to have_css('video.av-player__media[poster]')
      expect(rendered).to have_css('.av-player[data-av-player-audio-poster-value="false"]')
    end
  end

  # A Streaming Only video reaches here with downloadable false. v1's player told
  # the reader to download a file its own gate would then refuse; this must not.
  context 'when the viewer may not download the file' do
    before { render_player(mime: 'video/mp4', preview: nil, downloadable: false) }

    it 'still renders the player' do
      expect(rendered).to have_css('video.av-player__media')
    end

    it 'withholds the download-instead line' do
      expect(rendered).not_to have_css('.av-player__fallback')
      expect(rendered).not_to have_link('Download it')
    end
  end

  it 'offers the download-instead line when the viewer may download the file' do
    render_player(mime: 'video/mp4', preview: nil, downloadable: true)
    expect(rendered).to have_link('Download it')
  end

  describe 'captions' do
    it 'renders no <track> for a work without captions' do
      render_player(mime: 'video/mp4', preview: nil)
      expect(rendered).to have_no_css('track', visible: :all)
    end

    it 'renders the caption track inside the video element' do
      render_player(mime: 'video/mp4', preview: nil, caption: captions)
      expect(rendered).to have_css('video track[kind="captions"][src="/media/c-1"]', visible: :all)
    end

    it 'labels the track, since nothing records the real language' do
      render_player(mime: 'video/mp4', preview: nil, caption: captions)
      expect(rendered).to have_css('track[srclang="en"][label="English"]', visible: :all)
    end

    # /media, not /downloads: a caption is part of playing the file, so the
    # download gate a Streaming Only video closes must not take it down too.
    it 'serves the track from the media route even when the file may not be downloaded' do
      render_player(mime: 'video/mp4', preview: nil, downloadable: false, caption: captions)
      expect(rendered).to have_css('track[src="/media/c-1"]', visible: :all)
      expect(rendered).to have_no_link('Download it')
    end

    it 'renders the track inside a bare audio element too, if a work ever has one' do
      render_player(mime: 'audio/mpeg', preview: nil, caption: captions)
      expect(rendered).to have_css('audio track[kind="captions"]', visible: :all)
    end
  end
end
