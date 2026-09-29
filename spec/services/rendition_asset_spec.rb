# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RenditionAsset do
  def asset(noid, name, mime, role: 'original_file')
    AtlasRb::Mash.new('role' => role, 'noid' => noid, 'original_filename' => name, 'mime_type' => mime)
  end

  def file_sets(*assets)
    assets.map { |a| AtlasRb::Mash.new('assets' => [a]) }
  end

  def pdf_rendition(sets) = described_class.for(sets, mime_types: described_class::PDF)

  let(:word) { asset('b-doc', 'thesis.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') }

  it 'finds the PDF named after the Word original' do
    pdf = asset('b-pdf', 'thesis.pdf', 'application/pdf')

    expect(pdf_rendition(file_sets(word, pdf))['noid']).to eq('b-pdf')
  end

  # A PDF the depositor attached under another name is theirs, not a rendition.
  it 'ignores a PDF with a different name' do
    expect(pdf_rendition(file_sets(word, asset('b-pdf', 'appendix.pdf', 'application/pdf')))).to be_nil
  end

  it 'ignores assets that are not an original_file' do
    thumb = asset('b-thumb', 'thesis.pdf', 'application/pdf', role: 'thumbnail_image')

    expect(pdf_rendition(file_sets(word, thumb))).to be_nil
  end

  # Without another original to match, the PDF is the Work's own primary.
  it 'never treats a native PDF deposit as a rendition' do
    expect(pdf_rendition(file_sets(asset('b-pdf', 'thesis.pdf', 'application/pdf')))).to be_nil
  end

  it 'picks the same PDF every time when duplicates already exist' do
    later = asset('b-zz', 'thesis.pdf', 'application/pdf')
    earlier = asset('b-aa', 'thesis.pdf', 'application/pdf')

    expect(pdf_rendition(file_sets(word, later, earlier))['noid']).to eq('b-aa')
    expect(pdf_rendition(file_sets(earlier, word, later))['noid']).to eq('b-aa')
  end

  it 'answers nil for a Work with no file sets' do
    expect(pdf_rendition(nil)).to be_nil
  end

  describe 'an MP4 rendition of a video' do
    let(:mov) { asset('b-mov', 'talk.mov', 'video/quicktime') }

    def mp4_rendition(sets) = described_class.for(sets, mime_types: described_class::MP4)

    it 'finds the MP4 remuxed from the master' do
      mp4 = asset('b-mp4', 'talk.mp4', 'video/mp4')

      expect(mp4_rendition(file_sets(mov, mp4))['noid']).to eq('b-mp4')
    end

    # A master that is already an MP4 is never remuxed, so it has no rendition,
    # and must not be mistaken for one and overwritten.
    it 'never treats an MP4 master as its own rendition' do
      expect(mp4_rendition(file_sets(asset('b-mp4', 'talk.mp4', 'video/mp4')))).to be_nil
    end

    it 'does not look for a PDF when asked for an MP4' do
      pdf = asset('b-pdf', 'talk.pdf', 'application/pdf')

      expect(mp4_rendition(file_sets(mov, pdf))).to be_nil
    end
  end
end
