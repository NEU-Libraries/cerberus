# frozen_string_literal: true

require 'rails_helper'
require 'zip'

RSpec.describe XmlPreviewFile do
  let(:tmp_uploads) { Dir.mktmpdir('xml-preview-file') }
  let(:loader) { create(:loader, :xml) }
  let(:load_report) do
    LoadReport.create!(loader: loader, source_filename: 'batch.zip', status: :previewing,
                       parent_collection_id: 'neu:c1')
  end
  let(:dir) { File.join(tmp_uploads, 'load_reports', load_report.id.to_s) }
  let(:archive_path) { File.join(dir, 'batch.zip') }

  def create_row(file_name)
    XmlLoader::Manifest::Row.new(file_name: file_name, xml_path: 'record.xml')
  end

  # A zip holding the given entries, staged where the preview reads the archive.
  def stage_zip(entries)
    Zip::File.open(archive_path, create: true) do |zip|
      entries.each { |name, bytes| zip.get_output_stream(name) { |io| io.write(bytes) } }
    end
  end

  before do
    @orig = Rails.application.config.x.cerberus.uploads_root
    Rails.application.config.x.cerberus.uploads_root = tmp_uploads
    FileUtils.mkdir_p(dir)
  end

  after do
    Rails.application.config.x.cerberus.uploads_root = @orig
    FileUtils.rm_rf(tmp_uploads)
  end

  context 'with an image as the first row\'s file' do
    before { FileUtils.cp(Rails.root.join('spec/fixtures/files/xml_loader_create_sample.zip'), archive_path) }

    subject(:result) { described_class.call(load_report: load_report, row: create_row('flower.jpg')) }

    it 'gives its name, size and type, and an inline JPEG thumbnail' do
      expect(result.name).to eq('flower.jpg')
      expect(result.byte_size).to eq(104_297)
      expect(result.mime_type).to eq('image/jpeg')
      expect(result.thumbnail_src).to start_with('data:image/jpeg;base64,')
    end

    it 'makes the thumbnail no larger than 400 px, and keeps only the thumbnail' do
      result
      thumb = Vips::Image.new_from_file(File.join(dir, 'preview', 'thumbnail.jpg'))
      expect([thumb.width, thumb.height].max).to be <= 400
      expect(Dir.children(File.join(dir, 'preview'))).to eq(['thumbnail.jpg'])
    end

    # The show page builds the preview on every render.
    it 'reuses the cached thumbnail on a later render' do
      result
      expect(Vips::Image).not_to receive(:thumbnail)
      expect(described_class.call(load_report: load_report, row: create_row('flower.jpg')).thumbnail_src)
        .to eq(result.thumbnail_src)
    end
  end

  context 'with a file that has no picture' do
    before { stage_zip('talk.mp3' => 'x' * 5000) }

    it 'gives its size from the archive, and no thumbnail, without extracting it' do
      expect_any_instance_of(XmlLoader::Archive).not_to receive(:extract_one)
      result = described_class.call(load_report: load_report, row: create_row('talk.mp3'))

      expect(result.byte_size).to eq(5000)
      expect(result.mime_type).to eq('audio/mpeg')
      expect(result.thumbnail_src).to be_nil
    end
  end

  context 'with an image vips cannot read' do
    before { stage_zip('broken.jpg' => 'not a jpeg') }

    it 'falls back to no thumbnail rather than failing the preview' do
      result = described_class.call(load_report: load_report, row: create_row('broken.jpg'))
      expect(result.thumbnail_src).to be_nil
      expect(Dir.children(File.join(dir, 'preview'))).to eq(['no-thumbnail'])
    end

    # Else a corrupt multi-GB file would be extracted again on every render.
    it 'does not try again on a later render' do
      described_class.call(load_report: load_report, row: create_row('broken.jpg'))
      expect_any_instance_of(XmlLoader::Archive).not_to receive(:extract_one)
      described_class.call(load_report: load_report, row: create_row('broken.jpg'))
    end
  end

  it 'is nil when the archive does not hold the named file' do
    stage_zip('other.jpg' => 'x')
    expect(described_class.call(load_report: load_report, row: create_row('flower.jpg'))).to be_nil
  end

  context 'in update mode' do
    let(:row) { XmlLoader::Manifest::Row.new(identifier: 'abc1234', xml_path: 'record.xml') }

    it 'shows the existing Work\'s larger preview image' do
      allow(AtlasRb::Work).to receive(:find).with('abc1234').and_return(
        AtlasRb::Mash.new(preview: 'https://iiif.example/p.jpg', thumbnail: 'https://iiif.example/t.jpg')
      )
      expect(described_class.call(load_report: load_report, row: row).thumbnail_src).to eq('https://iiif.example/p.jpg')
    end

    it 'shows no thumbnail when the Work has none, or cannot be found' do
      allow(AtlasRb::Work).to receive(:find).and_return(AtlasRb::Mash.new(preview: nil), nil)
      expect(described_class.call(load_report: load_report, row: row).thumbnail_src).to be_nil
      expect(described_class.call(load_report: load_report, row: row).thumbnail_src).to be_nil
    end
  end
end
