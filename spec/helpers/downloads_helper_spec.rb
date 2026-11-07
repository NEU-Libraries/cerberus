# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DownloadsHelper, type: :helper do
  describe '#download_label' do
    it 'uses the label when there is one' do
      expect(helper.download_label(AtlasRb::Mash.new(label: 'PDF', use: 'original_file'))).to eq('PDF')
    end

    it 'falls back to the use when the label is blank' do
      expect(helper.download_label(AtlasRb::Mash.new(label: '', use: 'Image File'))).to eq('Image File')
    end
  end

  describe '#file_revisions_by_blob' do
    it 'keys each Blob\'s revisions by its noid, keeping their order' do
      revisions = [{ 'blob_id' => 'b1', 'revisions' => [{ 'revision' => 2 }, { 'revision' => 1 }] }]

      expect(helper.file_revisions_by_blob(revisions)['b1'].pluck('revision')).to eq([2, 1])
    end

    it 'treats a failed read (nil) as no revisions' do
      expect(helper.file_revisions_by_blob(nil)).to eq({})
    end
  end

  describe '#file_history_entries' do
    let(:pdf) { AtlasRb::Mash.new(noid: 'b1', label: 'PDF') }
    let(:image) { AtlasRb::Mash.new(noid: 'b2', label: 'Image') }
    let(:rendition) { AtlasRb::Mash.new(role: 'large_image', uri: 'https://g/x.jp2/full/pct:75/0/default.jpg') }
    let(:by_blob) { { 'b2' => [{ 'revision' => 2 }], 'b1' => [{ 'revision' => 3 }], 'b9' => [{ 'revision' => 2 }] } }

    it 'pairs each replaced file with its revisions, in the order of the files' do
      entries = helper.file_history_entries([pdf, image], by_blob)

      expect(entries.map { |file, _| file.noid }).to eq(%w[b1 b2])
    end

    # A Blob the Downloads card withholds is absent from the files, so it has
    # no entry either.
    it 'leaves out renditions, unreplaced files and Blobs that are not among the files' do
      entries = helper.file_history_entries([rendition, AtlasRb::Mash.new(noid: 'b5')], by_blob)

      expect(entries).to be_empty
    end
  end

  describe '#file_revision_date' do
    it 'shows the day alone, with the full timestamp on the time element' do
      html = Nokogiri::HTML.fragment(helper.file_revision_date('2026-11-04T16:48:11Z')).at_css('time')

      expect(html.text).to eq('4 November 2026')
      expect(html['datetime']).to start_with('2026-11-04T11:48:11')
    end

    it 'says so when the date cannot be read' do
      expect(helper.file_revision_date('not a date')).to include('date unknown')
    end
  end
end
