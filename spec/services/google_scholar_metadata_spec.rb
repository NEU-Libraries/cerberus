# frozen_string_literal: true

require 'rails_helper'

# Unit spec for the citation-tag value object. The citation is synthetic, in
# the shape AtlasRb::Work.citation returns; Atlas's Citation rule owns how a
# record becomes one. Here we own the gating and the field mapping.
RSpec.describe GoogleScholarMetadata do
  let(:permissions) { Struct.new(:read, :embargo).new(['public'], nil) }
  let(:files) do
    [{ noid: 'pdf123', uri: nil, mime_type: 'application/pdf' },
     { noid: 'img456', uri: nil, mime_type: 'image/jpeg' }]
  end
  let(:citation) do
    AtlasRb::Mash.new(
      'id'       => 'w123',
      'type'     => 'thesis',
      'title'    => 'A Study of Things',
      'author'   => [{ 'literal' => 'Lee, Wen-Han' }, { 'literal' => 'Northeastern University Libraries' }],
      'issued'   => { 'date-parts' => [[2023, 5, 1]] },
      'abstract' => 'An abstract about the work.',
      'keyword'  => 'Bioprinting, Rheology'
    )
  end

  subject(:meta) { described_class.new(citation: citation, permissions: permissions, files: files) }

  describe '#emit?' do
    it 'is true for a public work of each scholarly CSL type' do
      described_class::SCHOLAR_TYPES.each do |type|
        citation['type'] = type
        expect(meta.emit?).to be(true), "expected #{type} to emit"
      end
    end

    it 'is false for a non-scholarly CSL type' do
      citation['type'] = 'song'
      expect(meta.emit?).to be false
    end

    it 'is false when there is no citation' do
      meta = described_class.new(citation: nil, permissions: permissions, files: files)
      expect(meta.emit?).to be false
    end

    it 'is false when the work is not public' do
      permissions.read = ['northeastern:drs:repository:staff']
      expect(meta.emit?).to be false
    end
  end

  describe '.public?' do
    it 'is true only when read carries public' do
      expect(described_class.public?(permissions)).to be true
      expect(described_class.public?(Struct.new(:read).new(['northeastern:drs:repository:staff']))).to be false
      expect(described_class.public?(nil)).to be false
    end
  end

  describe '.citation_for' do
    it 'returns the citation Atlas serves' do
      allow(AtlasRb::Work).to receive(:citation).with('w123').and_return(citation)
      expect(described_class.citation_for('w123')).to eq(citation)
    end

    it 'degrades to nil when the read fails, so the show page still renders' do
      allow(AtlasRb::Work).to receive(:citation).and_raise(AtlasRb::ResourceError, 'GET /works/w123/citation → 503')
      expect(described_class.citation_for('w123')).to be_nil
    end
  end

  describe 'field mapping' do
    it 'maps title, authors, year, abstract and keywords from the citation' do
      expect(meta.title).to eq('A Study of Things')
      expect(meta.authors).to eq(['Lee, Wen-Han', 'Northeastern University Libraries'])
      expect(meta.publication_date).to eq('2023')
      expect(meta.abstract).to eq('An abstract about the work.')
      expect(meta.keywords).to eq('Bioprinting, Rheology')
    end

    it 'tolerates the keys Atlas leaves out' do
      meta = described_class.new(citation: AtlasRb::Mash.new('type' => 'report', 'title' => 'T'),
                                 permissions: permissions, files: [])
      expect(meta.authors).to eq([])
      expect(meta.keywords).to be_nil
      expect(meta.publication_date).to be_nil
      expect(meta.abstract).to be_nil
    end

    it 'gives no date for a literal date, which has no parts' do
      citation['issued'] = { 'literal' => 'circa 1900' }
      expect(meta.publication_date).to be_nil
    end
  end

  describe '#pdf_blob_noid' do
    it 'returns the first PDF Blob for a public, non-embargoed work' do
      expect(meta.pdf_blob_noid).to eq('pdf123')
    end

    it 'is nil when there is no PDF Blob' do
      meta = described_class.new(citation: citation, permissions: permissions,
                                 files: [{ noid: 'img', uri: nil, mime_type: 'image/jpeg' }])
      expect(meta.pdf_blob_noid).to be_nil
    end

    it 'ignores a Delegate derivative' do
      delegate = { noid: 'del', kind: 'Delegate', uri: 'https://iiif/x', mime_type: 'application/pdf' }
      meta = described_class.new(citation: citation, permissions: permissions, files: [delegate])
      expect(meta.pdf_blob_noid).to be_nil
    end

    it 'is nil when the work is private' do
      permissions.read = []
      expect(meta.pdf_blob_noid).to be_nil
    end

    it 'is nil while under a future embargo' do
      permissions.embargo = (Date.current + 30).to_s
      expect(meta.pdf_blob_noid).to be_nil
    end

    it 'is present once a past embargo has lapsed' do
      permissions.embargo = (Date.current - 1).to_s
      expect(meta.pdf_blob_noid).to eq('pdf123')
    end
  end
end
