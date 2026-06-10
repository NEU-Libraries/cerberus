# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultipagePreview do
  let(:tmp_uploads) { Dir.mktmpdir('multipage-preview') }
  let(:loader) { create(:loader, :multipage) }
  let(:archive_path) { zip_multipage_fixture(fixture_dir) }
  let(:load_report) do
    LoadReport.create!(loader: loader, source_filename: File.basename(archive_path),
                       status: :previewing, parent_collection_id: 'neu:c1')
  end

  subject(:result) { described_class.call(load_report: load_report) }

  # Stage the zipped fixture where the preview expects it. XSD validation is
  # stubbed so the spec doesn't hit the network (XmlValidator has its own
  # spec); the decorated render is stubbed at the Atlas boundary.
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

  context 'with the good multipage fixture' do
    let(:fixture_dir) { 'multipage' }

    it 'is ok with no errors of any kind' do
      expect(result).to be_ok
      expect(result.errors).to be_empty
    end

    it 'exposes the ordered pages and the MODS row' do
      expect(result.pages.map(&:file_name)).to eq(%w[bdr_43889.tif bdr_43890.tif])
      expect(result.pages.map(&:sequence)).to eq([1, 2])
      expect(result.mods_row.xml_path).to eq('bdr_43888.mods.xml')
    end

    it 'reads the MODS as UTF-8 and renders the decorated view' do
      expect(result.mods_xml).to include('<mods:mods')
      expect(result.mods_xml.encoding).to eq(Encoding::UTF_8)
      expect(result.decorated_html).to include('rendered')
    end
  end

  context 'with the bad-sequence fixture' do
    let(:fixture_dir) { 'multipage-bad-sequence' }

    it 'is blocked with both contract violations and makes no Atlas calls' do
      expect(result).to be_blocked
      expect(result.contract_errors.join)
        .to include('must run 1 through 2 with no gaps — got 1, 3')
        .and include('Last Item is flagged on Sequence 1')
      expect(AtlasRb::Resource).not_to have_received(:preview)
    end

    it 'still exposes the page list so the librarian can see what was read' do
      expect(result.pages.map(&:sequence)).to eq([1, 3])
    end
  end

  context 'with the no-mods fixture' do
    let(:fixture_dir) { 'multipage-no-mods' }

    it 'is blocked on the missing MODS file with no MODS pane' do
      expect(result).to be_blocked
      expect(result.contract_errors.join).to include("MODS XML file 'bdr_43888.mods.xml' was not found")
      expect(result.mods_xml).to be_nil
      expect(result.decorated_html).to be_nil
    end
  end

  context 'with invalid MODS content' do
    let(:fixture_dir) { 'multipage-invalid-mods' }

    before { allow(XmlValidator).to receive(:call).and_return(['MODS is not schema-valid.']) }

    it 'is blocked by the validator result' do
      expect(result).to be_blocked
      expect(result.mods_errors).to eq(['MODS is not schema-valid.'])
      expect(result.decorated_html).to be_nil
    end
  end

  context 'when the archive has no manifest' do
    let(:fixture_dir) { 'multipage' }

    before do
      # Re-stage a zip without the manifest entry.
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
    let(:fixture_dir) { 'multipage' }

    before { allow(AtlasRb::Resource).to receive(:preview).and_raise(Faraday::ConnectionFailed.new('down')) }

    it 'stays ok with a nil decorated_html (raw MODS still stands)' do
      expect(result).to be_ok
      expect(result.decorated_html).to be_nil
    end
  end
end
