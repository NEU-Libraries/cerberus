# frozen_string_literal: true

require 'caxlsx'

# Streams a collection's or set's metadata into an already-open zip_kit writer
# as a bundle the XML batch loader can re-ingest. It streams MODS *strings*
# rather than Blob bytes, so it does not include {ZipEntryWriter}. Gating lives
# in the `docs:` enumerator, not here. See docs/downloads.md.
class MetadataExportPacker
  # Must match XmlLoader::Manifest::COLUMN_LABELS, or the exported bundle no
  # longer loads back into the XML loader.
  HEADERS = ['PIDs', 'MODS XML File Path', 'File Name', 'Embargoed?', 'Embargo Date'].freeze

  # Every Solr field this packer reads off a doc, so a resolver's `fl` can be
  # taken from here instead of guessed. A field read but not fetched raises
  # nothing — the manifest just gets a blank cell that reads as "nothing to say".
  REQUIRED_DOC_FIELDS = %w[
    id
    alternate_ids_ssim
    embargo_release_date_dtsi
    embargoed_bsi
  ].freeze

  def initialize(docs:, include_mods: true)
    @docs = docs
    @include_mods = include_mods
  end

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

    # Solr stores the noid in `alternate_ids_ssim` as `id-<noid>`.
    def noid_of(doc)
      Array(doc['alternate_ids_ssim']).first.to_s.delete_prefix('id-').presence
    end

    # A fetch failure is recorded, never raised: once the response headers are
    # out the archive cannot be un-sent.
    def write_mods(zip, noid, errors)
      path = "mods/#{noid}.xml"
      zip.write_stored_file(path) { |sink| sink << AtlasRb::Work.mods(noid, 'xml') }
      path
    rescue Faraday::Error, JSON::ParserError => e
      errors << "#{noid}: MODS fetch failed — #{e.class}: #{e.message}"
      nil
    end

    # A row in HEADERS order.
    def manifest_row(doc, noid, xml_path)
      [noid, xml_path, nil, embargoed(doc), embargo_date(doc)]
    end

    # embargoed_bsi is boolean-as-string (Atlas's _bsi convention) — compare
    # against the string, not `true`.
    def embargoed(doc)
      'true' if Array(doc['embargo_release_date_dtsi']).first.present? ||
                Array(doc['embargoed_bsi']).first.to_s == 'true'
    end

    def embargo_date(doc)
      Array(doc['embargo_release_date_dtsi']).first.to_s[0, 10].presence
    end

    # The .xlsx is itself a zip — already compressed — so STORE, not deflate.
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
