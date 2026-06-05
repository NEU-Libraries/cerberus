# frozen_string_literal: true

require 'tempfile'

# Preview pass for the XML loader.
#
# Reads the staged archive's manifest plus the first data row's MODS XML —
# cheaply, without unpacking the whole archive — and reports what the batch
# *would* do, so the librarian can confirm before any Work is touched:
#
# - structural_errors: archive/manifest is unusable (no manifest, empty,
#   no header row). Blocks the confirm action entirely.
# - mode: :update (first row carries a NOID) or :create (file name, no NOID).
# - first_row / mods_xml: what the first row resolves to.
# - validation_errors: the first row's MODS run through XmlValidator, surfacing
#   missing-file / invalid-MODS problems before the run rather than during it.
#
# Per-row processing of the remaining rows happens in XmlIngestJob; this pass
# only inspects the first data row (v1's preview behaviour).
class XmlPreview < ApplicationService
  Result = Struct.new(:structural_errors, :mode, :first_row, :mods_xml, :validation_errors, keyword_init: true) do
    def blocked?
      structural_errors.any?
    end

    def ok?
      structural_errors.empty? && validation_errors.empty?
    end
  end

  def initialize(load_report:)
    @load_report = load_report
  end

  def call
    archive = XmlLoader::Archive.new(XmlLoader::Paths.archive_path(@load_report))

    manifest_bytes = archive.read('manifest.xlsx')
    return structural(['No manifest.xlsx was found in the uploaded archive.']) if manifest_bytes.nil?

    rows = parse_rows(manifest_bytes)
    return structural([@structural_error]) if @structural_error
    return structural(['The manifest has a header row but no data rows.']) if rows.empty?

    first = rows.first
    # Archive#read returns ASCII-8BIT (raw zip/tar bytes); the MODS is UTF-8
    # text, so re-tag it before it reaches the view's <pre> (HAML can't concat
    # a binary string into the UTF-8 output buffer) and the validator.
    mods = first.xml_path.present? ? archive.read(first.xml_path)&.force_encoding(Encoding::UTF_8) : nil

    Result.new(
      structural_errors: [],
      mode:              first.update? ? :update : :create,
      first_row:         first,
      mods_xml:          mods,
      validation_errors: row_errors(first, mods)
    )
  end

  private

    def parse_rows(manifest_bytes)
      Tempfile.create(['manifest', '.xlsx']) do |f|
        f.binmode
        f.write(manifest_bytes)
        f.flush
        return XmlLoader::Manifest.new(f.path).rows
      end
    rescue XmlLoader::Manifest::EmptyError, XmlLoader::Manifest::HeaderError => e
      @structural_error = e.message
      []
    end

    def row_errors(row, mods)
      if row.identifier.blank? && row.file_name.blank?
        return ['The first row has neither an identifier (update) nor a File Name (create).']
      end
      return ['The first row has no MODS XML File Path.'] if row.xml_path.blank?
      return ["MODS XML file '#{row.xml_path}' was not found in the archive."] if mods.nil?

      XmlValidator.call(xml: mods)
    end

    def structural(errors)
      Result.new(structural_errors: errors, mode: nil, first_row: nil, mods_xml: nil, validation_errors: [])
    end
end
