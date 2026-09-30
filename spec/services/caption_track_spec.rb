# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CaptionTrack do
  def asset(mime, uri: nil, noid: 'b-1')
    AtlasRb::Mash.new(noid: noid, mime_type: mime, uri: uri)
  end

  def caption(noid, language: nil, label: nil)
    AtlasRb::Mash.new(noid: noid, mime_type: 'text/vtt', language: language, track_label: label)
  end

  describe '.all' do
    it 'finds the WebVTT blobs among a work\'s assets' do
      files = [asset('video/mp4', noid: 'v-1'), asset('text/vtt', noid: 'c-1')]
      expect(described_class.all(files).map(&:noid)).to eq(%w[c-1])
    end

    it 'is empty when the work has no captions, and nil-safe before any asset read' do
      expect(described_class.all([asset('video/mp4')])).to eq([])
      expect(described_class.all(nil)).to eq([])
    end

    # A Delegate carries a uri and is a derivative, not content. None is text/vtt
    # today, but the same test guards MediaRemux.playable_file and the cost of
    # keeping them consistent is one clause.
    it 'ignores a delegate' do
      expect(described_class.all([asset('text/vtt', uri: 'https://iiif/x')])).to eq([])
    end

    # The first is the track a player turns on by default.
    it 'puts English first, then the rest by label' do
      files = [caption('c-fr', language: 'fr', label: 'Français'), caption('c-en'),
               caption('c-de', language: 'de', label: 'Deutsch')]
      expect(described_class.all(files).map(&:noid)).to eq(%w[c-en c-de c-fr])
    end
  end

  describe '.for_language' do
    let(:files) { [caption('c-en'), caption('c-es', language: 'es', label: 'Español')] }

    it 'finds the caption in that language, ignoring case' do
      expect(described_class.for_language(files, 'ES').noid).to eq('c-es')
    end

    # Every caption stored before Atlas kept a language was offered as English,
    # so an English upload replaces it rather than sitting beside it.
    it 'takes a caption with no recorded language to be English' do
      expect(described_class.for_language(files, 'en').noid).to eq('c-en')
    end

    it 'is nil for a language the work has no caption in' do
      expect(described_class.for_language(files, 'fr')).to be_nil
    end
  end

  describe '.label' do
    it 'uses the recorded label' do
      expect(described_class.label(caption('c', language: 'es', label: 'Castellano'))).to eq('Castellano')
    end

    it 'falls back to a listed language\'s own name, then to the bare tag' do
      expect(described_class.label(caption('c', language: 'fr'))).to eq('Français')
      expect(described_class.label(caption('c', language: 'cy'))).to eq('cy')
      expect(described_class.label(caption('c'))).to eq('English')
    end
  end

  describe '.choice' do
    it 'reads a listed language as its tag and own name' do
      expect(described_class.choice('es')).to eq(%w[es Español])
    end

    it 'refuses a tag the list does not offer, or none at all' do
      expect(described_class.choice('xx')).to be_nil
      expect(described_class.choice(nil)).to be_nil
    end

    it 'reads Other from its tag and label fields, trimmed' do
      expect(described_class.choice('other', other_tag: ' es-MX ', other_label: ' Español (México) '))
        .to eq(['es-MX', 'Español (México)'])
    end

    it 'refuses Other with a malformed tag, no label, or an overlong label' do
      expect(described_class.choice('other', other_tag: 'spanish!', other_label: 'Español')).to be_nil
      expect(described_class.choice('other', other_tag: 'es', other_label: ' ')).to be_nil
      expect(described_class.choice('other', other_tag: 'es', other_label: 'x' * 65)).to be_nil
    end
  end

  describe '.applicable?' do
    it 'offers the field on a work with a video blob' do
      expect(described_class.applicable?([asset('video/mp4')])).to be(true)
    end

    it 'offers the field on a work with an audio blob' do
      expect(described_class.applicable?([asset('audio/mpeg')])).to be(true)
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
