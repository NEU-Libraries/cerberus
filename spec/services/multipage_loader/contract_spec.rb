# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultipageLoader::Contract do
  def row(file_name: 'page.tif', xml_path: nil, sequence: nil, last_item: false, title: nil)
    MultipageLoader::Manifest::Row.new(
      file_name: file_name, title: title, xml_path: xml_path,
      sequence_raw: sequence, last_item_raw: last_item
    )
  end

  def good_rows
    [
      row(file_name: 'work.mods.xml', xml_path: 'work.mods.xml', sequence: 0),
      row(file_name: 'p1.tif', sequence: 1),
      row(file_name: 'p2.tif', sequence: 2, last_item: true)
    ]
  end

  def good_files
    Set['work.mods.xml', 'p1.tif', 'p2.tif', 'manifest.xlsx']
  end

  def errors_for(rows, files = good_files)
    described_class.call(rows: rows, present_files: files)
  end

  it 'passes a well-formed manifest with all files present' do
    expect(errors_for(good_rows)).to be_empty
  end

  it 'flags a row with no File Name' do
    rows = good_rows + [row(file_name: nil, sequence: 3)]
    expect(errors_for(rows)).to include('Manifest row 4: missing File Name.')
  end

  it 'flags a non-integer Sequence with the row file name' do
    rows = good_rows + [row(file_name: 'p3.tif', sequence: 'three')]
    expect(errors_for(rows).join).to include("row 4 ('p3.tif')").and include('whole number')
  end

  it 'requires exactly one Sequence 0 row' do
    no_mods = good_rows[1..]
    expect(errors_for(no_mods).join).to include('exactly one Sequence 0 row').and include('none found')

    two_mods = good_rows + [row(file_name: 'extra.mods.xml', xml_path: 'extra.mods.xml', sequence: 0)]
    expect(errors_for(two_mods).join).to include('found 2')
  end

  it 'requires the Sequence 0 row to carry the MODS path' do
    rows = good_rows
    rows[0] = row(file_name: 'work.mods.xml', xml_path: nil, sequence: 0)
    expect(errors_for(rows)).to include('The Sequence 0 row must give the MODS XML File Path.')
  end

  it 'requires at least one page row' do
    rows = [good_rows.first]
    expect(errors_for(rows)).to include('The manifest has no page rows (Sequence 1 and up).')
  end

  it 'flags duplicate sequences' do
    rows = good_rows + [row(file_name: 'p2-again.tif', sequence: 2)]
    expect(errors_for(rows).join).to include('Sequence 2 appears on more than one row')
  end

  it 'flags non-contiguous page sequences' do
    rows = [good_rows.first, row(file_name: 'p1.tif', sequence: 1), row(file_name: 'p3.tif', sequence: 3, last_item: true)]
    expect(errors_for(rows)).to include('Page sequences must run 1 through 2 with no gaps — got 1, 3.')
  end

  it 'requires exactly one Last Item flag' do
    none = [good_rows[0], good_rows[1], row(file_name: 'p2.tif', sequence: 2)]
    expect(errors_for(none).join).to include('Exactly one row must have Last Item set to TRUE — found 0')

    both = [good_rows[0], row(file_name: 'p1.tif', sequence: 1, last_item: true), good_rows[2]]
    expect(errors_for(both).join).to include('found 2')
  end

  it 'requires Last Item on the highest page sequence' do
    rows = [good_rows[0], row(file_name: 'p1.tif', sequence: 1, last_item: true), row(file_name: 'p2.tif', sequence: 2)]
    expect(errors_for(rows).join).to include('Last Item is flagged on Sequence 1').and include('highest page sequence is 2')
  end

  it 'flags missing page files and missing MODS files' do
    errors = errors_for(good_rows, Set['work.mods.xml', 'p1.tif'])
    expect(errors).to include("Page file 'p2.tif' (Sequence 2) was not found in the archive.")

    errors = errors_for(good_rows, Set['p1.tif', 'p2.tif'])
    expect(errors).to include("MODS XML file 'work.mods.xml' was not found in the archive.")
  end

  describe 'against the real fixtures' do
    def fixture_rows(dir)
      MultipageLoader::Manifest.new(
        Rails.root.join('spec/fixtures/files', dir, 'manifest.xlsx').to_s
      ).rows
    end

    def fixture_files(dir)
      Dir.children(Rails.root.join('spec/fixtures/files', dir))
         .reject { |f| f.end_with?('Zone.Identifier') }.to_set
    end

    it 'accepts the good multipage fixture' do
      expect(errors_for(fixture_rows('multipage'), fixture_files('multipage'))).to be_empty
    end

    it 'rejects the bad-sequence fixture for both the gap and the misplaced Last Item' do
      errors = errors_for(fixture_rows('multipage-bad-sequence'), fixture_files('multipage-bad-sequence'))
      expect(errors.join).to include('must run 1 through 2 with no gaps — got 1, 3')
        .and include('Last Item is flagged on Sequence 1')
    end

    it 'rejects the no-mods fixture for the absent MODS file' do
      errors = errors_for(fixture_rows('multipage-no-mods'), fixture_files('multipage-no-mods'))
      expect(errors.join).to include("MODS XML file 'bdr_43888.mods.xml' was not found")
    end
  end
end
