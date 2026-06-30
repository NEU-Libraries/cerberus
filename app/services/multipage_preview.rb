# frozen_string_literal: true

require 'tempfile'

# Preview pass for the multipage loader — a "did I upload the right
# spreadsheet?" sanity check, not a full validation report.
#
# A manifest concatenates many items (see MultipageLoader::ItemSet). The
# preview deliberately scopes to the **first item**: it groups the rows (cheap
# — just parsing) to report how many items the sheet holds, then shows that
# first item in detail (its ordered pages and its MODS, raw beside Atlas's
# rendered view). It does NOT contract-validate the whole batch — that is the
# run-time per-item job's work (MultipageItemJob), and front-running it here
# would both duplicate that work and overload the librarian with a per-item
# problem list before they have even confirmed.
#
# Only structural problems (no manifest, empty, no header row, no data rows,
# no items) block confirm. A bad individual item is caught and skipped at run
# time, surfaced in the load report.
class MultipagePreview < ApplicationService
  Result = Struct.new(:structural_errors, :item_count, :page_count,
                      :first_item, :mods_xml, :mods_errors, :decorated_html,
                      keyword_init: true) do
    # Confirm is blocked only when the archive itself is unusable.
    def blocked?
      structural_errors.any?
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

    build_result(archive, items)
  end

  private

    # Scope is the first item only: its pages come from grouping, and its MODS
    # is read and schema-checked just to decide whether the rendered pane can
    # show. Items 2..n are counted but not validated here.
    def build_result(archive, items)
      first = items.first
      mods = read_mods(archive, first)
      mods_errors = mods ? XmlValidator.call(xml: mods) : []

      Result.new(
        structural_errors: [],
        item_count:        items.size,
        page_count:        items.sum { |item| item.pages.size },
        first_item:        first,
        mods_xml:          mods,
        mods_errors:       mods_errors,
        # Only render the decorated view when the sample MODS validated —
        # Atlas's renderer expects well-formed, schema-valid input.
        decorated_html:    mods_errors.empty? && mods ? decorated(mods) : nil
      )
    end

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
    # back nil — the run-time job will report it on that item.
    def read_mods(archive, item)
      xml_path = item&.xml_path
      return nil if xml_path.blank?

      archive.read(File.basename(xml_path))&.force_encoding(Encoding::UTF_8)
    end

    def structural(errors)
      Result.new(structural_errors: errors, item_count: 0, page_count: 0,
                 first_item: nil, mods_xml: nil, mods_errors: [], decorated_html: nil)
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
