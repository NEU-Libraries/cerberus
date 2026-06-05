# frozen_string_literal: true

require 'rails_helper'

RSpec.describe XmlPreview do
  let(:tmp_uploads) { Dir.mktmpdir('xml-preview') }
  let(:loader) { create(:loader, :xml) }
  let(:load_report) do
    LoadReport.create!(loader: loader, source_filename: fixture, status: :previewing,
                       parent_collection_id: 'neu:c1')
  end

  # Stage the fixture archive where XmlPreview expects it, then run the real
  # service against it. XSD validation is stubbed so the spec doesn't hit the
  # network (XmlValidator has its own spec).
  before do
    @orig = Rails.application.config.x.cerberus.uploads_root
    Rails.application.config.x.cerberus.uploads_root = tmp_uploads
    dir = File.join(tmp_uploads, 'load_reports', load_report.id.to_s)
    FileUtils.mkdir_p(dir)
    FileUtils.cp(Rails.root.join("spec/fixtures/files/#{fixture}"), File.join(dir, fixture))
    allow(XmlValidator).to receive(:call).and_return([])
  end

  after do
    Rails.application.config.x.cerberus.uploads_root = @orig
    FileUtils.rm_rf(tmp_uploads)
  end

  context 'with a valid single-row update archive' do
    let(:fixture) { 'metadata_existing_file.zip' }

    subject(:result) { described_class.call(load_report: load_report) }

    it 'is not blocked and detects update mode' do
      expect(result).not_to be_blocked
      expect(result.mode).to eq(:update)
    end

    it 'exposes the first row and its MODS, with no validation errors' do
      expect(result.first_row.identifier).to eq('neu:test123')
      expect(result.mods_xml).to include('<mods:mods')
      expect(result.validation_errors).to be_empty
      expect(result).to be_ok
    end
  end

  context 'when the archive has no manifest' do
    let(:fixture) { 'zip_without_manifest.zip' }

    it 'is blocked with a structural error' do
      result = described_class.call(load_report: load_report)
      expect(result).to be_blocked
      expect(result.structural_errors.join).to match(/No manifest/i)
    end
  end

  context 'when the manifest has no recognizable header' do
    let(:fixture) { 'no_header.zip' }

    it 'is blocked with the header error surfaced as structural' do
      result = described_class.call(load_report: load_report)
      expect(result).to be_blocked
      expect(result.structural_errors.join).to match(/header/i)
    end
  end

  context 'when the first row MODS fails validation' do
    let(:fixture) { 'metadata_existing_file.zip' }

    before { allow(XmlValidator).to receive(:call).and_return(['Document must declare xmlns:mods']) }

    it 'is not blocked but surfaces the validation errors' do
      result = described_class.call(load_report: load_report)
      expect(result).not_to be_blocked
      expect(result.validation_errors).to include('Document must declare xmlns:mods')
      expect(result).not_to be_ok
    end
  end
end
