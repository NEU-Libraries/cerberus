# frozen_string_literal: true

require 'caxlsx'
require 'zip'

# Builds a multipage loader archive (manifest.xlsx + MODS + page files) on the
# fly from a lightweight item spec, so multi-item and skip-bad scenarios need
# no committed binary fixtures. The page/MODS payloads are tiny dummy bytes —
# specs that exercise this stub the Atlas writes and XSD validation, so real
# TIFFs/MODS aren't needed. The committed single-item fixtures still cover the
# real-bytes path.
module MultipageArchiveBuilder
  Item = Struct.new(:mods, :title, :pages, keyword_init: true)

  # One item-block: a Sequence 0 MODS row followed by ordered page rows, Last
  # Item on the final page. `last_item_on:` overrides which page sequence
  # carries the flag (for the misplaced-flag case); `pages: []` builds a
  # page-less item.
  def multipage_item(mods:, pages:, title: 'Untitled')
    Item.new(mods: mods, title: title, pages: pages)
  end

  # items: array of multipage_item(...). Builds the manifest and writes the
  # referenced files. `omit_files:` references a name in the manifest without
  # placing it in the archive (missing-file cases). Returns the zip path.
  def build_multipage_archive(items, omit_files: [])
    dir = Dir.mktmpdir('multipage-built')
    build_manifest(File.join(dir, 'manifest.xlsx'), items)
    items.each do |item|
      write_archive_file(dir, item.mods, mods_xml(item.title)) unless omit_files.include?(item.mods)
      item.pages.each { |p| write_archive_file(dir, p, "bytes:#{p}") unless omit_files.include?(p) }
    end
    zip_dir(dir)
  end

  # Lowest-level escape hatch: supply explicit row tuples
  # [file_name, title, xml_path, sequence, last_item] and the files to include.
  def build_multipage_archive_from_rows(rows, files)
    dir = Dir.mktmpdir('multipage-built')
    write_manifest_rows(File.join(dir, 'manifest.xlsx'), rows)
    files.each { |name, content| write_archive_file(dir, name, content) }
    zip_dir(dir)
  end

  def mods_xml(title)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <mods:mods xmlns:mods="http://www.loc.gov/mods/v3">
        <mods:titleInfo><mods:title>#{title}</mods:title></mods:titleInfo>
      </mods:mods>
    XML
  end

  private

    def build_manifest(path, items)
      rows = items.flat_map do |item|
        [[item.mods, item.title, item.mods, 0, nil]] +
          item.pages.each_with_index.map do |page, i|
            [page, item.title, item.mods, i + 1, i == item.pages.size - 1 ? true : nil]
          end
      end
      write_manifest_rows(path, rows)
    end

    def write_manifest_rows(path, rows)
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Manifest') do |sheet|
        sheet.add_row ['File Name', 'Title', 'MODS XML File Path', 'Sequence', 'Last Item']
        rows.each { |row| sheet.add_row(row) }
      end
      package.serialize(path)
    end

    def write_archive_file(dir, name, content)
      File.binwrite(File.join(dir, name), content)
    end

    def zip_dir(dir)
      out = File.join(dir, 'archive.zip')
      Zip::File.open(out, create: true) do |zip|
        Dir.children(dir).reject { |f| f == 'archive.zip' }.sort.each { |f| zip.add(f, File.join(dir, f)) }
      end
      out
    end
end

RSpec.configure { |config| config.include MultipageArchiveBuilder }
