# frozen_string_literal: true

require 'rails_helper'
require 'tempfile'

RSpec.describe XmlLoader::Manifest do
  # Pull the manifest out of a real fixture archive and parse it, so the spec
  # exercises the same roo path the loader uses in production.
  def manifest_for(zip)
    bytes = XmlLoader::Archive.new(Rails.root.join("spec/fixtures/files/#{zip}").to_s).read('manifest.xlsx')
    file  = Tempfile.new(['manifest', '.xlsx'])
    file.binmode
    file.write(bytes)
    file.flush
    described_class.new(file.path)
  end

  describe '#rows' do
    context 'a single-row update manifest (metadata_existing_file.zip)' do
      subject(:rows) { manifest_for('metadata_existing_file.zip').rows }

      it 'parses one row in update mode keyed by the identifier' do
        expect(rows.length).to eq(1)
        expect(rows.first).to have_attributes(
          identifier: 'neu:test123',
          xml_path:   'sample_mods_with_handle.xml'
        )
        expect(rows.first).to be_update
      end
    end

    context 'a multi-row update manifest with v2 NOIDs (metadata_existing_files.zip)' do
      subject(:rows) { manifest_for('metadata_existing_files.zip').rows }

      it 'parses every data row in update mode' do
        expect(rows.length).to eq(5)
        expect(rows).to all(be_update)
        expect(rows.map(&:identifier)).to include('8j2RtvbFW')
        expect(rows.map(&:xml_path)).to include('sample_mods_with_handle_0.xml')
      end
    end

    # Built here, because no fixture archive carries the column. The header is
    # matched case-insensitively, as every other column is.
    context 'a manifest with a Darwin Core column' do
      subject(:rows) do
        path = File.join(Dir.mktmpdir('manifest'), 'manifest.xlsx')
        pkg = Axlsx::Package.new
        pkg.workbook.add_worksheet(name: 'Manifest') do |sheet|
          sheet.add_row ['PIDs', 'MODS XML File Path', 'Darwin Core XML File Path']
          sheet.add_row ['noid-1', 'rec-1.xml', 'rec-1-dwc.xml']
          sheet.add_row ['noid-2', 'rec-2.xml', '']
        end
        pkg.serialize(path)
        described_class.new(path).rows
      end

      it 'reads the record path, and leaves a blank cell as no record' do
        expect(rows.map(&:dwc_path)).to eq(['rec-1-dwc.xml', nil])
      end
    end

    context 'a manifest with no recognizable header (no_header.zip)' do
      it 'raises HeaderError' do
        expect { manifest_for('no_header.zip').rows }.to raise_error(described_class::HeaderError)
      end
    end
  end

  describe XmlLoader::Manifest::Row do
    it 'is update? when an identifier is present' do
      expect(described_class.new(identifier: 'noid-1')).to be_update
    end

    it 'is create? when a file name is present and no identifier' do
      row = described_class.new(file_name: 'photo.jpg')
      expect(row).to be_create
      expect(row).not_to be_update
    end

    it 'is embargoed? case-insensitively on the literal "true"' do
      expect(described_class.new(embargoed: 'TRUE')).to be_embargoed
      expect(described_class.new(embargoed: 'no')).not_to be_embargoed
      expect(described_class.new(embargoed: nil)).not_to be_embargoed
    end
  end
end
