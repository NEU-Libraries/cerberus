# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultipageLoader::ItemSet do
  def row(file_name:, sequence:, xml_path: nil, last_item: false)
    MultipageLoader::Manifest::Row.new(file_name: file_name, xml_path: xml_path,
                                       sequence_raw: sequence, last_item_raw: last_item)
  end

  it 'is empty for no rows' do
    expect(described_class.call(rows: [])).to eq([])
  end

  it 'groups a single Last-Item-terminated block into one item' do
    rows = [
      row(file_name: 'm', xml_path: 'm', sequence: 0),
      row(file_name: 'p1', sequence: 1),
      row(file_name: 'p2', sequence: 2, last_item: true)
    ]
    items = described_class.call(rows: rows)

    expect(items.size).to eq(1)
    expect(items.first.index).to eq(0)
    expect(items.first.mods_row.file_name).to eq('m')
    expect(items.first.pages.map(&:file_name)).to eq(%w[p1 p2])
  end

  it 'splits at each Last Item boundary and resets sequence per item' do
    rows = [
      row(file_name: 'a', xml_path: 'a', sequence: 0),
      row(file_name: 'a1', sequence: 1, last_item: true),
      row(file_name: 'b', xml_path: 'b', sequence: 0),
      row(file_name: 'b1', sequence: 1),
      row(file_name: 'b2', sequence: 2, last_item: true)
    ]
    items = described_class.call(rows: rows)

    expect(items.map(&:index)).to eq([0, 1])
    expect(items[0].xml_path).to eq('a')
    expect(items[0].pages.map(&:sequence)).to eq([1])
    expect(items[1].xml_path).to eq('b')
    expect(items[1].pages.map(&:sequence)).to eq([1, 2])
  end

  it 'returns a trailing block with no closing flag as an item' do
    rows = [
      row(file_name: 'a', xml_path: 'a', sequence: 0),
      row(file_name: 'a1', sequence: 1, last_item: true),
      row(file_name: 'b', xml_path: 'b', sequence: 0),
      row(file_name: 'b1', sequence: 1)
    ]
    items = described_class.call(rows: rows)

    expect(items.size).to eq(2)
    expect(items.first.last_item_present?).to be(true)
    expect(items.last.last_item_present?).to be(false)
  end
end
