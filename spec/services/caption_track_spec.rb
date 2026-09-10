# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CaptionTrack do
  def asset(mime, uri: nil, noid: 'b-1')
    AtlasRb::Mash.new(noid: noid, mime_type: mime, uri: uri)
  end

  describe '.for' do
    it 'finds the WebVTT blob among a work\'s assets' do
      files = [asset('video/mp4', noid: 'v-1'), asset('text/vtt', noid: 'c-1')]
      expect(described_class.for(files).noid).to eq('c-1')
    end

    it 'returns nil when the work has no captions' do
      expect(described_class.for([asset('video/mp4')])).to be_nil
    end

    it 'is nil-safe, since a show page can render before any asset read' do
      expect(described_class.for(nil)).to be_nil
    end

    # A Delegate carries a uri and is a derivative, not content. None is text/vtt
    # today, but the same test guards MediaRemux.playable_file and the cost of
    # keeping them consistent is one clause.
    it 'ignores a delegate' do
      expect(described_class.for([asset('text/vtt', uri: 'https://iiif/x')])).to be_nil
    end
  end

  describe '.applicable?' do
    it 'offers the field on a work with a video blob' do
      expect(described_class.applicable?([asset('video/mp4')])).to be(true)
    end

    it 'withholds it on audio, which the port did not cover' do
      expect(described_class.applicable?([asset('audio/mpeg')])).to be(false)
    end

    it 'withholds it on an image work' do
      expect(described_class.applicable?([asset('image/tiff')])).to be(false)
    end

    it 'withholds it when the work has no assets yet' do
      expect(described_class.applicable?(nil)).to be(false)
    end
  end

  describe '.accepted?' do
    it 'accepts a .vtt upload' do
      expect(described_class.accepted?('lecture.vtt')).to be(true)
    end

    it 'accepts it whatever the case of the extension' do
      expect(described_class.accepted?('LECTURE.VTT')).to be(true)
    end

    # The one format v1 took that a browser cannot read. Refusing it at the form
    # is the whole reason this predicate exists.
    it 'refuses an .srt upload' do
      expect(described_class.accepted?('lecture.srt')).to be(false)
    end

    it 'refuses a file with no extension, and a missing filename' do
      expect(described_class.accepted?('lecture')).to be(false)
      expect(described_class.accepted?(nil)).to be(false)
    end
  end
end
