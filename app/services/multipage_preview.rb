# frozen_string_literal: true

require 'tempfile'

# Preview pass for the multipage loader.
#
# Unlike XmlPreview (first row only — each row is an independent Work),
# this validates the WHOLE manifest: the archive becomes a single Work, so
# one bad page invalidates everything and there is nothing useful a
# partially-valid archive can do. The manifest is KB-scale, so the full
# pass is still cheap — page images are presence-checked via the archive
# directory (Archive#basenames), never extracted.
#
# - structural_errors: archive/manifest unusable (no manifest, empty, no
#   header row, no data rows).
# - contract_errors: MultipageLoader::Contract violations (sequence
#   integrity, Last Item placement, missing files).
# - mods_errors: the Work's MODS run through XmlValidator.
#
# Any error blocks confirm; MultipageUnzipJob re-runs the same checks as
# the enforcement point, so a forced confirm still can't mint anything.
class MultipagePreview < ApplicationService
  Result = Struct.new(:structural_errors, :contract_errors, :mods_errors, :mods_row, :pages,
                      :mods_xml, :decorated_html, keyword_init: true) do
    def blocked?
      structural_errors.any? || contract_errors.any? || mods_errors.any?
    end

    def ok?
      !blocked?
    end

    def errors
      structural_errors + contract_errors + mods_errors
    end
  end

  def initialize(load_report:)
    @load_report = load_report
  end

  # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  # The early-return guards (no manifest / unparseable / no rows) read as
  # one linear preview flow, mirroring XmlPreview#call.
  def call
    archive = XmlLoader::Archive.new(XmlLoader::Paths.archive_path(@load_report))

    manifest_bytes = archive.read('manifest.xlsx')
    return structural(['No manifest.xlsx was found in the uploaded archive.']) if manifest_bytes.nil?

    rows = parse_rows(manifest_bytes)
    return structural([@structural_error]) if @structural_error
    return structural(['The manifest has a header row but no data rows.']) if rows.empty?

    contract_errors = MultipageLoader::Contract.call(rows: rows, present_files: archive.basenames)
    mods = read_mods(archive, rows)
    mods_errors = mods ? XmlValidator.call(xml: mods) : []

    Result.new(
      structural_errors: [],
      contract_errors:   contract_errors,
      mods_errors:       mods_errors,
      mods_row:          rows.find(&:mods_row?),
      pages:             rows.select(&:page?).sort_by(&:sequence),
      mods_xml:          mods,
      # Only render the decorated view for archives that validated clean —
      # Atlas's renderer expects well-formed, schema-valid input.
      decorated_html:    contract_errors.empty? && mods_errors.empty? && mods ? decorated(mods) : nil
    )
  end
  # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  private

    def parse_rows(manifest_bytes)
      Tempfile.create(['manifest', '.xlsx']) do |f|
        f.binmode
        f.write(manifest_bytes)
        f.flush
        return MultipageLoader::Manifest.new(f.path).rows
      end
    rescue MultipageLoader::Manifest::EmptyError, MultipageLoader::Manifest::HeaderError => e
      @structural_error = e.message
      []
    end

    # The Work's MODS bytes, re-tagged UTF-8 for the view and validator
    # (Archive#read returns raw ASCII-8BIT zip/tar bytes). A missing file
    # comes back nil — the Contract has already reported it.
    def read_mods(archive, rows)
      xml_path = rows.find(&:mods_row?)&.xml_path
      return nil if xml_path.blank?

      archive.read(File.basename(xml_path))&.force_encoding(Encoding::UTF_8)
    end

    def structural(errors)
      Result.new(structural_errors: errors, contract_errors: [], mods_errors: [],
                 mods_row: nil, pages: [], mods_xml: nil, decorated_html: nil)
    end

    # Same best-effort decorated render as XmlPreview: if Atlas is
    # unreachable the raw column still stands on its own.
    def decorated(mods)
      Tempfile.create(['preview_mods', '.xml']) do |f|
        f.write(mods)
        f.flush
        AtlasRb::Resource.preview(f.path)
      end
    rescue Faraday::Error => e
      Rails.logger.warn("MultipagePreview: decorated render unavailable (#{e.class}: #{e.message})")
      nil
    end
end
