# frozen_string_literal: true

require 'rails_helper'

# Exercises the real Ghostscript txtwrite extraction (gs ships in the container).
RSpec.describe PdfText, type: :service do
  let(:pdf) { Rails.root.join('spec/fixtures/files/example.pdf').to_s }

  it 'extracts the text layer of a PDF' do
    # gs txtwrite preserves the PDF's literal glyph spacing, so assert on
    # distinctive single words rather than a multi-word phrase.
    text = described_class.call(source_path: pdf)
    expect(text).to match(/consectetur/i).and match(/ipsum/i)
  end

  it 'returns nil for a path Ghostscript cannot read (never raises)' do
    expect(described_class.call(source_path: '/no/such/file.pdf')).to be_nil
  end

  it 'reports availability from the gs binary' do
    expect(described_class.available?).to be(true)
  end
end
