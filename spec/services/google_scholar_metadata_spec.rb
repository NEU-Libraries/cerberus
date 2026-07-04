# frozen_string_literal: true

require 'rails_helper'

# Unit spec for the citation-tag value object. All inputs are synthetic — the
# real Solr projection is the Atlas CitationIndexer's concern; here we own the
# gating + the field mapping from an already-indexed doc.
RSpec.describe GoogleScholarMetadata do
  let(:work) { Struct.new(:title).new('A Study of Things') }
  let(:permissions) { Struct.new(:read, :embargo).new(['public'], nil) }
  let(:files) do
    [{ noid: 'pdf123', uri: nil, mime_type: 'application/pdf' },
     { noid: 'img456', uri: nil, mime_type: 'image/jpeg' }]
  end
  let(:solr_doc) do
    { 'genre_ssim'       => ['Theses & Dissertations'],
      'creator_ssim'     => ['Lee, Wen-Han', 'Northeastern University Libraries'],
      'keyword_ssim'     => %w[Bioprinting Rheology],
      'pub_date_ssim'    => ['2023'],
      'description_tsim' => ['An abstract about the work.'] }
  end

  subject(:meta) { described_class.new(work: work, permissions: permissions, files: files, solr_doc: solr_doc) }

  describe '#emit?' do
    it 'is true for a public, scholarly-genre work' do
      expect(meta.emit?).to be true
    end

    it 'is false for a non-scholarly genre' do
      solr_doc['genre_ssim'] = ['podcasts']
      expect(meta.emit?).to be false
    end

    it 'is false for a work with no genre' do
      solr_doc.delete('genre_ssim')
      expect(meta.emit?).to be false
    end

    it 'is false when the work is not public' do
      permissions.read = ['northeastern:drs:repository:staff']
      expect(meta.emit?).to be false
    end
  end

  describe 'field mapping' do
    it 'maps title, authors, date, abstract, keywords from the work + Solr doc' do
      expect(meta.title).to eq('A Study of Things')
      expect(meta.authors).to eq(['Lee, Wen-Han', 'Northeastern University Libraries'])
      expect(meta.publication_date).to eq('2023')
      expect(meta.abstract).to eq('An abstract about the work.')
      expect(meta.keywords).to eq(%w[Bioprinting Rheology])
    end

    it 'tolerates missing optional fields' do
      doc = { 'genre_ssim' => ['Technical Reports'] }
      m = described_class.new(work: work, permissions: permissions, files: [], solr_doc: doc)
      expect(m.authors).to eq([])
      expect(m.keywords).to eq([])
      expect(m.publication_date).to be_nil
      expect(m.abstract).to be_nil
    end
  end

  describe '#pdf_blob_noid' do
    it 'returns the first PDF Blob for a public, non-embargoed work' do
      expect(meta.pdf_blob_noid).to eq('pdf123')
    end

    it 'is nil when there is no PDF Blob' do
      meta = described_class.new(work: work, permissions: permissions,
                                 files: [{ noid: 'img', uri: nil, mime_type: 'image/jpeg' }], solr_doc: solr_doc)
      expect(meta.pdf_blob_noid).to be_nil
    end

    it 'ignores a Delegate derivative that carries a uri' do
      delegate = { noid: 'del', uri: 'https://iiif/x', mime_type: 'application/pdf' }
      meta = described_class.new(work: work, permissions: permissions, files: [delegate], solr_doc: solr_doc)
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
