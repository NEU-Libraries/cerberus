# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PdfRenditionAsset do
  def asset(noid, name, mime, role: 'original_file')
    AtlasRb::Mash.new('role' => role, 'noid' => noid, 'original_filename' => name, 'mime_type' => mime)
  end

  def file_sets(*assets)
    assets.map { |a| AtlasRb::Mash.new('assets' => [a]) }
  end

  let(:word) { asset('b-doc', 'thesis.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') }

  it 'finds the PDF named after the Word original' do
    pdf = asset('b-pdf', 'thesis.pdf', 'application/pdf')

    expect(described_class.for(file_sets(word, pdf))['noid']).to eq('b-pdf')
  end

  # A PDF the depositor attached under another name is theirs, not a rendition.
  it 'ignores a PDF with a different name' do
    expect(described_class.for(file_sets(word, asset('b-pdf', 'appendix.pdf', 'application/pdf')))).to be_nil
  end

  it 'ignores assets that are not an original_file' do
    thumb = asset('b-thumb', 'thesis.pdf', 'application/pdf', role: 'thumbnail_image')

    expect(described_class.for(file_sets(word, thumb))).to be_nil
  end

  # Without another original to match, the PDF is the Work's own primary.
  it 'never treats a native PDF deposit as a rendition' do
    expect(described_class.for(file_sets(asset('b-pdf', 'thesis.pdf', 'application/pdf')))).to be_nil
  end

  it 'picks the same PDF every time when duplicates already exist' do
    later = asset('b-zz', 'thesis.pdf', 'application/pdf')
    earlier = asset('b-aa', 'thesis.pdf', 'application/pdf')

    expect(described_class.for(file_sets(word, later, earlier))['noid']).to eq('b-aa')
    expect(described_class.for(file_sets(earlier, word, later))['noid']).to eq('b-aa')
  end

  it 'answers nil for a Work with no file sets' do
    expect(described_class.for(nil)).to be_nil
  end
end
