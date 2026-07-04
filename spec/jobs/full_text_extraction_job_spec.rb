# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FullTextExtractionJob, type: :job do
  let(:work_id) { 'w-1' }
  let(:tmp) { Dir.mktmpdir }
  let(:fixtures) { Rails.root.join('spec/fixtures/files') }

  after { FileUtils.rm_rf(tmp) }

  it 'extracts a PDF via PdfText and PATCHes the text to the Work' do
    pdf = File.join(tmp, 'doc.pdf')
    FileUtils.cp(fixtures.join('example.pdf'), pdf)
    allow(PdfText).to receive(:call).with(source_path: pdf).and_return('Lorem ipsum body text')

    expect(AtlasRb::Work).to receive(:set_full_text).with(work_id, text: 'Lorem ipsum body text')
    described_class.new.perform(work_id, pdf)
  end

  it 'reads plain text directly' do
    txt = File.join(tmp, 'notes.txt')
    File.write(txt, 'plain body words')

    expect(AtlasRb::Work).to receive(:set_full_text).with(work_id, text: 'plain body words')
    described_class.new.perform(work_id, txt)
  end

  it 'no-ops when the source file is missing' do
    expect(AtlasRb::Work).not_to receive(:set_full_text)
    described_class.new.perform(work_id, File.join(tmp, 'gone.pdf'))
  end

  it 'no-ops when extraction yields no text (e.g. an image-only PDF)' do
    pdf = File.join(tmp, 'scan.pdf')
    FileUtils.cp(fixtures.join('example.pdf'), pdf)
    allow(PdfText).to receive(:call).and_return('')

    expect(AtlasRb::Work).not_to receive(:set_full_text)
    described_class.new.perform(work_id, pdf)
  end

  it 'skips non-extractable types (e.g. images)' do
    img = File.join(tmp, 'pic.png')
    FileUtils.cp(fixtures.join('image.png'), img)

    expect(AtlasRb::Work).not_to receive(:set_full_text)
    described_class.new.perform(work_id, img)
  end
end
