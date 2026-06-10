# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultipageLoader::Manifest do
  def fixture_manifest(dir)
    Rails.root.join('spec/fixtures/files', dir, 'manifest.xlsx').to_s
  end

  describe '#rows against the multipage fixture' do
    subject(:rows) { described_class.new(fixture_manifest('multipage')).rows }

    it 'maps the header columns and yields one row per data row' do
      expect(rows.size).to eq(3)
      expect(rows.map(&:file_name)).to eq(%w[bdr_43888.mods.xml bdr_43889.tif bdr_43890.tif])
    end

    it 'coerces sequences to integers, 0 marking the MODS row' do
      expect(rows.map(&:sequence)).to eq([0, 1, 2])
      expect(rows.first).to be_mods_row
      expect(rows.last(2)).to all(be_page)
    end

    it 'reads the Last Item boolean only on the final row' do
      expect(rows.map(&:last_item?)).to eq([false, false, true])
    end

    it 'carries the MODS path and title through as strings' do
      expect(rows.first.xml_path).to eq('bdr_43888.mods.xml')
      expect(rows.first.title).to eq('Youngs Gap Casino, Parksville, N.Y.')
    end
  end

  describe '#rows against the bad-sequence fixture' do
    it 'parses the out-of-order sequences as-is (the Contract judges them)' do
      rows = described_class.new(fixture_manifest('multipage-bad-sequence')).rows
      expect(rows.map(&:sequence)).to eq([0, 3, 1])
      expect(rows.map(&:last_item?)).to eq([false, false, true])
    end
  end

  describe '#rows against the no-mods fixture' do
    it 'skips trailing blank rows' do
      rows = described_class.new(fixture_manifest('multipage-no-mods')).rows
      expect(rows.size).to eq(3)
      expect(rows.map(&:file_name)).to all(be_present)
    end
  end

  describe 'Row sequence coercion' do
    def row_with(sequence_raw)
      described_class::Row.new(file_name: 'x.tif', sequence_raw: sequence_raw)
    end

    it 'accepts whole floats and digit strings' do
      expect(row_with(2.0).sequence).to eq(2)
      expect(row_with('2').sequence).to eq(2)
      expect(row_with('2.0').sequence).to eq(2)
    end

    it 'rejects negatives, fractions, and junk as nil' do
      expect(row_with(-1).sequence).to be_nil
      expect(row_with(1.5).sequence).to be_nil
      expect(row_with('three').sequence).to be_nil
      expect(row_with(nil).sequence).to be_nil
    end
  end

  describe 'Row last_item? coercion' do
    def row_with(last_item_raw)
      described_class::Row.new(file_name: 'x.tif', last_item_raw: last_item_raw)
    end

    it 'accepts a real boolean and the string TRUE in any case' do
      expect(row_with(true)).to be_last_item
      expect(row_with('TRUE')).to be_last_item
      expect(row_with(' true ')).to be_last_item
    end

    it 'is false for false, blanks, and anything else' do
      expect(row_with(false)).not_to be_last_item
      expect(row_with(nil)).not_to be_last_item
      expect(row_with('yes')).not_to be_last_item
    end
  end
end
