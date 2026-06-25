# frozen_string_literal: true

require 'caxlsx'

# Streams a collection's / set's metadata into an already-open zip_kit writer as
# a re-ingestable bundle: a `manifest.xlsx` in the exact column shape the XML
# batch loader reads ({XmlLoader::Manifest}), plus, optionally, one
# `mods/<noid>.xml` per item. It is the inverse of the XML loader — export the
# records, edit the MODS offline, re-feed the bundle as updates (every row
# carries a NOID, so {XmlLoader::Manifest::Row#update?} is true for all of them).
#
# Mirrors the SetZipPacker / {ZipEntryWriter} posture (STORE, flat memory,
# mid-stream error capture) but streams MODS *strings* from Atlas rather than
# Blob bytes, so it does not include {ZipEntryWriter}. The manifest itself is a
# small text grid — accrued in memory and written as the final entry once every
# item has been visited; only the MODS payloads stream.
#
# +docs+ is anything responding to `each_content_batch { |solr_docs| ... }`
# (SetResolver and CollectionContentsResolver both do). The gating lives in that
# enumerator — it yields only the Works the requesting user can discover — so the
# packer stays auth-agnostic.
class MetadataExportPacker
  # Header row, matching XmlLoader::Manifest::COLUMN_LABELS so the bundle loads
  # straight back into the XML loader. `PIDs` is v1's column name for what is now
  # a NOID; the loader accepts either.
  HEADERS = ['PIDs', 'MODS XML File Path', 'File Name', 'Embargoed?', 'Embargo Date'].freeze

  # @param docs [#each_content_batch] a gated contents resolver.
  # @param include_mods [Boolean] also bundle one mods/<noid>.xml per item.
  def initialize(docs:, include_mods: true)
    @docs = docs
    @include_mods = include_mods
  end

  # @param zip [ZipKit::Streamer] an open writer (from `zip_kit_stream`).
  # @return [void]
  def pack(zip)
    rows = []
    errors = []

    @docs.each_content_batch do |docs|
      docs.each do |doc|
        noid = noid_of(doc)
        next if noid.blank?

        xml_path = write_mods(zip, noid, errors) if @include_mods
        rows << manifest_row(doc, noid, xml_path)
      end
    end

    write_manifest(zip, rows)
    write_text(zip, 'ERRORS.txt', errors.join("\n")) if errors.any?
  end

  private

    # Solr stores the noid in `alternate_ids_ssim` as `id-<noid>` (same idiom as
    # SetZipPacker#noid_of).
    def noid_of(doc)
      Array(doc['alternate_ids_ssim']).first.to_s.delete_prefix('id-').presence
    end

    # Stream one Work's MODS into `mods/<noid>.xml`; return the in-bundle path for
    # the manifest. A fetch failure is recorded, not raised — the archive can't be
    # un-sent once headers are out (same posture as ZipEntryWriter#write_asset).
    # @return [String, nil] the manifest path, or nil if the fetch failed.
    def write_mods(zip, noid, errors)
      path = "mods/#{noid}.xml"
      zip.write_stored_file(path) { |sink| sink << AtlasRb::Work.mods(noid, 'xml') }
      path
    rescue Faraday::Error, JSON::ParserError => e
      errors << "#{noid}: MODS fetch failed — #{e.class}: #{e.message}"
      nil
    end

    # A manifest row in HEADERS order. File Name is left blank — for an
    # update-oriented export (every row has a NOID) the loader does not require
    # it. Embargo columns are best-effort from Solr and otherwise blank, kept so
    # the spreadsheet stays a faithful re-ingest template.
    def manifest_row(doc, noid, xml_path)
      [noid, xml_path, nil, embargoed(doc), embargo_date(doc)]
    end

    def embargoed(doc)
      'true' if Array(doc['embargo_release_date_dtsi']).first.present? ||
                Array(doc['embargoed_bsi']).first == true
    end

    def embargo_date(doc)
      Array(doc['embargo_release_date_dtsi']).first.to_s[0, 10].presence
    end

    # Build the workbook in memory (small text even at the export cap) and write
    # it as the final stored entry. The .xlsx is itself a zip — already
    # compressed — so STORE, not deflate.
    def write_manifest(zip, rows)
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Manifest') do |sheet|
        sheet.add_row HEADERS
        rows.each { |row| sheet.add_row row }
      end
      write_text(zip, 'manifest.xlsx', package.to_stream.read)
    end

    def write_text(zip, name, body)
      zip.write_stored_file(name) { |sink| sink << body.to_s }
    end
end
