# frozen_string_literal: true

module MultipageLoader
  # Validates a single item-block's rows against the multipage archive
  # contract, returning user-facing error strings (valid iff empty). This runs
  # per item in the preview (advisory) and again in MultipageUnzipJob (the
  # enforcement point), so a contract-invalid item is recorded as failed and
  # skipped before any Work is minted. MODS schema validation is *not* here —
  # it is per-item network/CPU work the item job owns (see MultipageItemJob).
  #
  # The contract, scoped to one item: exactly one Sequence 0 row naming the
  # item's MODS XML; page sequences run 1..n contiguous and unique; the item
  # ends in a Last Item flag on its final page; every referenced file exists
  # in the archive.
  class Contract < ApplicationService
    # item: a MultipageLoader::Item.
    # present_files: Set of basenames actually present in the archive.
    def initialize(item:, present_files:)
      @item = item
      @present_files = present_files
    end

    def call
      # Rows failing the basic shape checks are excluded from the aggregate
      # rules so one malformed cell doesn't cascade into noise.
      shape_errors, well_formed = check_row_shapes
      shape_errors +
        mods_row_errors(well_formed) +
        page_errors(well_formed) +
        last_item_errors(well_formed) +
        file_presence_errors(well_formed)
    end

    private

      def check_row_shapes
        errors = []
        well_formed = []
        # Row numbers are item-relative; the item's label (caller-supplied)
        # locates which item in the sheet a message belongs to.
        @item.rows.each.with_index(1) do |row, n|
          if row.file_name.blank?
            errors << "Row #{n}: missing File Name."
          elsif row.sequence.nil?
            errors << "Row #{n} ('#{row.file_name}'): Sequence must be a whole number — " \
                      '0 for the MODS row, 1 and up for pages.'
          else
            well_formed << row
          end
        end
        [errors, well_formed]
      end

      def mods_row_errors(rows)
        mods_rows = rows.select(&:mods_row?)
        case mods_rows.size
        when 0
          ['This item must contain exactly one Sequence 0 row carrying the MODS XML — none found.']
        when 1
          return [] if mods_rows.first.xml_path.present?

          ['The Sequence 0 row must give the MODS XML File Path.']
        else
          ["This item must contain exactly one Sequence 0 row — found #{mods_rows.size}."]
        end
      end

      def page_errors(rows)
        pages = rows.select(&:page?)
        return ['This item has no page rows (Sequence 1 and up).'] if pages.empty?

        errors = duplicate_sequence_errors(rows)
        sorted = pages.map(&:sequence).sort
        unless sorted == (1..pages.size).to_a
          errors << "Page sequences must run 1 through #{pages.size} with no gaps — got #{sorted.join(', ')}."
        end
        errors
      end

      def duplicate_sequence_errors(rows)
        rows.group_by(&:sequence).filter_map do |sequence, group|
          next if group.size < 2

          "Sequence #{sequence} appears on more than one row — sequences must be unique."
        end
      end

      # ItemSet closes a block on each Last Item flag, so within a well-formed
      # item the flag is on the final row and at most one exists. A trailing
      # block with no flag is an incomplete item; a flag off the highest page
      # means the librarian flagged the wrong row.
      def last_item_errors(rows)
        pages = rows.select(&:page?)
        flagged = rows.select(&:last_item?)
        return ['This item has no Last Item flag — its final page must be flagged TRUE.'] if flagged.empty?
        return [] if pages.empty? # the no-pages rule already fired

        max = pages.map(&:sequence).max
        return [] if flagged.first.sequence == max

        ["Last Item is flagged on Sequence #{flagged.first.sequence}, " \
         "but the highest page sequence is #{max} — flag the final page."]
      end

      def file_presence_errors(rows)
        page_file_errors(rows) + mods_file_errors(rows)
      end

      def page_file_errors(rows)
        rows.select(&:page?).filter_map do |row|
          next if @present_files.include?(row.file_name)

          "Page file '#{row.file_name}' (Sequence #{row.sequence}) was not found in the archive."
        end
      end

      def mods_file_errors(rows)
        mods_row = rows.find { |row| row.mods_row? && row.xml_path.present? }
        return [] if mods_row.nil? || @present_files.include?(File.basename(mods_row.xml_path))

        ["MODS XML file '#{mods_row.xml_path}' was not found in the archive."]
      end
  end
end
