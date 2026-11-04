# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DownloadsHelper, type: :helper do
  let(:pdf) { AtlasRb::Mash.new(noid: 'b1', label: 'PDF', use: 'original_file') }
  let(:image) { AtlasRb::Mash.new(noid: 'b2', label: '', use: 'Image File') }
  let(:rendition) { AtlasRb::Mash.new(role: 'large_image', uri: 'https://g/x.jp2/full/pct:75/0/default.jpg') }

  def revisions_for(blob_id, *ordinals)
    { 'blob_id'   => blob_id,
      'revisions' => ordinals.map { |n| { 'revision' => n, 'created' => "2026-10-0#{n}T12:00:00Z" } } }
  end

  describe '#download_label' do
    it 'uses the label when there is one' do
      expect(helper.download_label(pdf)).to eq('PDF')
    end

    it 'falls back to the use when the label is blank' do
      expect(helper.download_label(image)).to eq('Image File')
    end
  end

  describe '#file_history_entries' do
    it 'pairs each listed file with its revisions, in the order of the files' do
      revisions = [revisions_for('b2', 2, 1), revisions_for('b1', 3, 2, 1)]

      entries = helper.file_history_entries([pdf, image], revisions)

      expect(entries.map { |file, _| file.noid }).to eq(%w[b1 b2])
      expect(entries.first.last.pluck('revision')).to eq([3, 2, 1])
    end

    # A Blob the Downloads card withholds is absent from `files`, so its
    # history stays off the page too.
    it 'leaves out a revised Blob that is not among the files' do
      entries = helper.file_history_entries([pdf], [revisions_for('b9', 2, 1)])

      expect(entries).to be_empty
    end

    it 'leaves out renditions and files that were never replaced' do
      entries = helper.file_history_entries([rendition, image], [revisions_for('b1', 2, 1)])

      expect(entries).to be_empty
    end

    it 'treats a failed read (nil) as no history' do
      expect(helper.file_history_entries([pdf], nil)).to be_empty
    end
  end
end
