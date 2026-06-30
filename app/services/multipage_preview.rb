# frozen_string_literal: true

require 'tempfile'

# Preview pass for the multipage loader — a "did I upload the right
# spreadsheet?" sanity check, not a full validation report.
#
# A manifest concatenates many items (see MultipageLoader::ItemSet). This
# groups the rows, contract-validates every item locally (cheap), and reports
# batch totals plus the **first item** in detail (its ordered pages and its
# MODS, raw beside Atlas's rendered view). Only the first item's MODS is
# schema-validated — the per-item MODS check is the item job's job at run time,
# and rendering every item would be pointless for a thousand-item sheet.
#
# - structural_errors: archive/manifest unusable (no manifest, empty, no
#   header row, no data rows, no items). These block confirm.
# - invalid_items: items that fail the contract; they don't block confirm
#   (skip-bad, ingest-valid) but are surfaced so the librarian sees what will
#   be skipped. Confirm is blocked only if *no* item is valid.
class MultipagePreview < ApplicationService
  InvalidItem = Struct.new(:label, :errors, keyword_init: true)

  Result = Struct.new(:structural_errors, :item_count, :page_count, :valid_count, :invalid_count,
                      :invalid_items, :first_item, :mods_xml, :mods_errors, :decorated_html,
                      keyword_init: true) do
    # Confirm is blocked only when the archive is unusable or nothing valid
    # remains to ingest — a few bad items among many valid ones still runs.
    def blocked?
      structural_errors.any? || valid_count.to_i.zero?
    end

    def ok?
      !blocked?
    end
  end

  def initialize(load_report:)
    @load_report = load_report
  end

  # The early-return guards (no manifest / unparseable / no rows / no items)
  # read as one linear preview flow, mirroring XmlPreview#call.
  def call
    archive = XmlLoader::Archive.new(XmlLoader::Paths.archive_path(@load_report))

    manifest_bytes = archive.read('manifest.xlsx')
    return structural(['No manifest.xlsx was found in the uploaded archive.']) if manifest_bytes.nil?

    rows = parse_rows(manifest_bytes)
    return structural([@structural_error]) if @structural_error
    return structural(['The manifest has a header row but no data rows.']) if rows.empty?

    items = MultipageLoader::ItemSet.call(rows: rows)
    return structural(['The manifest produced no items.']) if items.empty?

    summarize(archive, items)
  end

  private

    def summarize(archive, items)
      present = archive.basenames
      validated = items.map { |item| [item, MultipageLoader::Contract.call(item: item, present_files: present)] }
      build_result(archive, items, validated)
    end

    # rubocop:disable Metrics/MethodLength
    # The Result carries every field the preview view reads; assembling it is
    # one flat literal, not branching logic.
    def build_result(archive, items, validated)
      invalid = validated.reject { |_item, errors| errors.empty? }
      first = items.first
      mods = read_mods(archive, first)
      mods_errors = mods ? XmlValidator.call(xml: mods) : []

      Result.new(
        structural_errors: [],
        item_count:        items.size,
        page_count:        items.sum { |item| item.pages.size },
        valid_count:       validated.size - invalid.size,
        invalid_count:     invalid.size,
        # Cap the surfaced list — a sheet can have thousands of items; the
        # count above conveys the scale, this names the first handful.
        invalid_items:     invalid.first(25).map { |item, errors| InvalidItem.new(label: item.label, errors: errors) },
        first_item:        first,
        mods_xml:          mods,
        mods_errors:       mods_errors,
        # Only render the decorated view when the sample MODS validated —
        # Atlas's renderer expects well-formed, schema-valid input.
        decorated_html:    mods_errors.empty? && mods ? decorated(mods) : nil
      )
    end
    # rubocop:enable Metrics/MethodLength

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

    # The sample item's MODS bytes, re-tagged UTF-8 for the view and validator
    # (Archive#read returns raw ASCII-8BIT zip/tar bytes). A missing file comes
    # back nil — the Contract has already reported it on that item.
    def read_mods(archive, item)
      xml_path = item&.xml_path
      return nil if xml_path.blank?

      archive.read(File.basename(xml_path))&.force_encoding(Encoding::UTF_8)
    end

    def structural(errors)
      Result.new(structural_errors: errors, item_count: 0, page_count: 0, valid_count: 0, invalid_count: 0,
                 invalid_items: [], first_item: nil, mods_xml: nil, mods_errors: [], decorated_html: nil)
    end

    # Same best-effort decorated render as XmlPreview: if Atlas is unreachable
    # the raw column still stands on its own.
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
