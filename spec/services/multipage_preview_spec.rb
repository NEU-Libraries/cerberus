# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultipagePreview do
  let(:tmp_uploads) { Dir.mktmpdir('multipage-preview') }
  let(:loader) { create(:loader, :multipage) }
  let(:load_report) do
    LoadReport.create!(loader: loader, source_filename: File.basename(archive_path),
                       status: :previewing, parent_collection_id: 'neu:c1')
  end

  subject(:result) { described_class.call(load_report: load_report) }

  # Stage the archive where the preview expects it. XSD validation is stubbed
  # so specs don't hit the network (XmlValidator has its own spec); the
  # decorated render is stubbed at the Atlas boundary.
  before do
    @orig = Rails.application.config.x.cerberus.uploads_root
    Rails.application.config.x.cerberus.uploads_root = tmp_uploads
    dir = File.join(tmp_uploads, 'load_reports', load_report.id.to_s)
    FileUtils.mkdir_p(dir)
    FileUtils.cp(archive_path, File.join(dir, File.basename(archive_path)))
    allow(XmlValidator).to receive(:call).and_return([])
    allow(AtlasRb::Resource).to receive(:preview).and_return('<dl class="mods-display">rendered</dl>')
  end

  after do
    Rails.application.config.x.cerberus.uploads_root = @orig
    FileUtils.rm_rf(tmp_uploads)
  end

  context 'with the good single-item fixture' do
    let(:archive_path) { zip_multipage_fixture('multipage') }

    it 'is ok with one valid item and no skipped items' do
      expect(result).to be_ok
      expect(result.item_count).to eq(1)
      expect(result.valid_count).to eq(1)
      expect(result.invalid_count).to eq(0)
      expect(result.page_count).to eq(2)
    end

    it 'exposes the first item: ordered pages and the MODS row' do
      expect(result.first_item.pages.map(&:file_name)).to eq(%w[bdr_43889.tif bdr_43890.tif])
      expect(result.first_item.pages.map(&:sequence)).to eq([1, 2])
      expect(result.first_item.mods_row.xml_path).to eq('bdr_43888.mods.xml')
    end

    it 'reads the first item MODS as UTF-8 and renders the decorated view' do
      expect(result.mods_xml).to include('<mods:mods')
      expect(result.mods_xml.encoding).to eq(Encoding::UTF_8)
      expect(result.mods_errors).to be_empty
      expect(result.decorated_html).to include('rendered')
    end
  end

  context 'with multiple valid items (built archive)' do
    let(:archive_path) do
      build_multipage_archive([
                                multipage_item(mods: 'a.mods.xml', pages: %w[a1.tif a2.tif], title: 'Item A'),
                                multipage_item(mods: 'b.mods.xml', pages: %w[b1.tif], title: 'Item B')
                              ])
    end

    it 'reports batch totals and shows the first item as the sample' do
      expect(result).to be_ok
      expect(result.item_count).to eq(2)
      expect(result.valid_count).to eq(2)
      expect(result.page_count).to eq(3)
      expect(result.first_item.label).to eq('Item A')
      expect(result.first_item.pages.map(&:file_name)).to eq(%w[a1.tif a2.tif])
    end
  end

  context 'when one item is invalid (skip-bad)' do
    # Item B references a MODS file that is not in the archive — invalid — while
    # item A is whole. Confirm still runs (skip-bad), surfacing the skipped one.
    let(:archive_path) do
      build_multipage_archive(
        [
          multipage_item(mods: 'a.mods.xml', pages: %w[a1.tif a2.tif], title: 'Item A'),
          multipage_item(mods: 'b.mods.xml', pages: %w[b1.tif], title: 'Item B')
        ],
        omit_files: ['b.mods.xml']
      )
    end

    it 'stays ok with one valid item and names the skipped one' do
      expect(result).to be_ok
      expect(result.valid_count).to eq(1)
      expect(result.invalid_count).to eq(1)
      expect(result.invalid_items.first.label).to eq('Item B')
      expect(result.invalid_items.first.errors.join).to include("MODS XML file 'b.mods.xml' was not found")
    end
  end

  context 'when no item is valid' do
    let(:archive_path) do
      build_multipage_archive([multipage_item(mods: 'a.mods.xml', pages: %w[a1.tif], title: 'Item A')],
                              omit_files: ['a.mods.xml'])
    end

    it 'is blocked because there is nothing to ingest' do
      expect(result).to be_blocked
      expect(result.valid_count).to eq(0)
      expect(result.invalid_count).to eq(1)
    end
  end

  context 'with the no-mods fixture (single invalid item)' do
    let(:archive_path) { zip_multipage_fixture('multipage-no-mods') }

    it 'is blocked on the missing MODS file with no MODS pane' do
      expect(result).to be_blocked
      expect(result.invalid_items.map(&:errors).join).to include("MODS XML file 'bdr_43888.mods.xml' was not found")
      expect(result.mods_xml).to be_nil
      expect(result.decorated_html).to be_nil
    end
  end

  context 'when the first item MODS is schema-invalid' do
    let(:archive_path) { zip_multipage_fixture('multipage-invalid-mods') }

    before { allow(XmlValidator).to receive(:call).and_return(['MODS is not schema-valid.']) }

    it 'still confirms (per-item MODS is the item job\'s gate) but flags the sample' do
      expect(result).to be_ok
      expect(result.mods_errors).to eq(['MODS is not schema-valid.'])
      expect(result.decorated_html).to be_nil
    end
  end

  context 'when the archive has no manifest' do
    let(:archive_path) { zip_multipage_fixture('multipage') }

    before do
      dir = File.join(tmp_uploads, 'load_reports', load_report.id.to_s)
      staged = File.join(dir, File.basename(archive_path))
      Zip::File.open(staged) { |zip| zip.remove(zip.find_entry('manifest.xlsx')) }
    end

    it 'reports the structural error' do
      expect(result).to be_blocked
      expect(result.structural_errors).to eq(['No manifest.xlsx was found in the uploaded archive.'])
    end
  end

  context 'when the decorated render is unavailable' do
    let(:archive_path) { zip_multipage_fixture('multipage') }

    before { allow(AtlasRb::Resource).to receive(:preview).and_raise(Faraday::ConnectionFailed.new('down')) }

    it 'stays ok with a nil decorated_html (raw MODS still stands)' do
      expect(result).to be_ok
      expect(result.decorated_html).to be_nil
    end
  end
end
