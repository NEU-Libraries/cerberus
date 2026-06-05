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
  Result = Struct.new(:structural_errors, :mode, :first_row, :mods_xml, :validation_errors,
                      :decorated_html, keyword_init: true) do
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

  # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  # The early-return guards (no manifest / unparseable / no rows) read as one
  # linear preview flow; extracting them would scatter the structural-error
  # handling that is the method's whole point.
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
    mods   = first.xml_path.present? ? archive.read(first.xml_path)&.force_encoding(Encoding::UTF_8) : nil
    errors = row_errors(first, mods)

    Result.new(
      structural_errors: [],
      mode:              first.update? ? :update : :create,
      first_row:         first,
      mods_xml:          mods,
      validation_errors: errors,
      # Only render the decorated view for MODS that validated — Atlas's
      # renderer expects well-formed, schema-valid input (mirrors the XML
      # editor, which previews only when there are no errors).
      decorated_html:    errors.empty? && mods ? decorated(mods) : nil
    )
  end
  # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

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
      Result.new(structural_errors: errors, mode: nil, first_row: nil, mods_xml: nil,
                 validation_errors: [], decorated_html: nil)
    end

    # Atlas renders the MODS to its HTML display the same way the XML editor's
    # live preview does (POST /resources/preview). Best-effort: if Atlas is
    # unreachable the raw column still stands on its own.
    def decorated(mods)
      Tempfile.create(['preview_mods', '.xml']) do |f|
        f.write(mods)
        f.flush
        AtlasRb::Resource.preview(f.path)
      end
    rescue Faraday::Error => e
      Rails.logger.warn("XmlPreview: decorated render unavailable (#{e.class}: #{e.message})")
      nil
    end
end
