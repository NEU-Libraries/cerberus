# frozen_string_literal: true

module MultipageLoader
  # Validates parsed manifest rows against the multipage archive contract,
  # returning user-facing error strings (valid iff empty). This runs in the
  # preview (advisory) and again in MultipageUnzipJob (the enforcement
  # point) — a bad archive must be rejected before anything is created in
  # Atlas, because one bad page invalidates the whole Work.
  #
  # The contract: exactly one Sequence 0 row naming the Work's MODS XML;
  # page sequences run 1..n contiguous and unique; Last Item is flagged on
  # exactly the final page; every referenced file exists in the archive.
  class Contract < ApplicationService
    # rows: MultipageLoader::Manifest::Row list.
    # present_files: Set of basenames actually present in the archive.
    def initialize(rows:, present_files:)
      @rows = rows
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
        @rows.each.with_index(1) do |row, n|
          if row.file_name.blank?
            errors << "Manifest row #{n}: missing File Name."
          elsif row.sequence.nil?
            errors << "Manifest row #{n} ('#{row.file_name}'): Sequence must be a whole number — " \
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
          ["The manifest must contain exactly one Sequence 0 row carrying the Work's MODS XML — none found."]
        when 1
          return [] if mods_rows.first.xml_path.present?

          ['The Sequence 0 row must give the MODS XML File Path.']
        else
          ["The manifest must contain exactly one Sequence 0 row — found #{mods_rows.size}."]
        end
      end

      def page_errors(rows)
        pages = rows.select(&:page?)
        return ['The manifest has no page rows (Sequence 1 and up).'] if pages.empty?

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

      def last_item_errors(rows)
        pages = rows.select(&:page?)
        flagged = rows.select(&:last_item?)
        return ["Exactly one row must have Last Item set to TRUE — found #{flagged.size}."] if flagged.size != 1
        return [] if pages.empty? # the no-pages rule already fired

        max = pages.map(&:sequence).max
        return [] if flagged.first.sequence == max

        ["Last Item is flagged on Sequence #{flagged.first.sequence}, " \
         "but the highest page sequence is #{max} — flag the final page."]
      end

      def file_presence_errors(rows)
        errors = rows.select(&:page?).filter_map do |row|
          next if @present_files.include?(row.file_name)

          "Page file '#{row.file_name}' (Sequence #{row.sequence}) was not found in the archive."
        end
        mods_row = rows.find { |row| row.mods_row? && row.xml_path.present? }
        if mods_row && !@present_files.include?(File.basename(mods_row.xml_path))
          errors << "MODS XML file '#{mods_row.xml_path}' was not found in the archive."
        end
        errors
      end
  end
end
