# frozen_string_literal: true

require 'roo'

module MultipageLoader
  # Parses a multipage manifest.xlsx into normalized rows.
  #
  # Same skeleton as XmlLoader::Manifest (case-insensitive, whitespace-
  # tolerant header matching; EmptyError/HeaderError for structural
  # problems) but a different column set and row semantics: Sequence 0 is
  # the row carrying the Work's MODS XML, 1..n are the ordered pages.
  #
  # Unlike the XML manifest's all-string columns, Sequence and Last Item
  # arrive from Roo as whatever Excel stored — Integer, Float, String, or
  # a real boolean — so the Row keeps the raw cell and coerces on read.
  class Manifest
    class EmptyError < StandardError; end
    class HeaderError < StandardError; end

    Row = Struct.new(:file_name, :title, :xml_path, :sequence_raw, :last_item_raw, keyword_init: true) do
      # Integer page/MODS order, or nil when the cell isn't a whole
      # non-negative number (callers treat nil as a contract violation).
      def sequence
        value = coerce_sequence(sequence_raw)
        value if value && value >= 0
      end

      # Typed coercion only; the sign check lives in #sequence (the String
      # pattern already excludes negatives, the numeric types don't).
      def coerce_sequence(raw)
        case raw
        when Integer then raw
        when Float   then (raw % 1).zero? ? raw.to_i : nil
        when String  then raw.strip.match?(/\A\d+(\.0+)?\z/) ? raw.strip.to_i : nil
        end
      end

      def last_item?
        last_item_raw == true || last_item_raw.to_s.strip.casecmp?('true')
      end

      def mods_row?
        sequence&.zero? || false
      end

      def page?
        sequence&.positive? || false
      end
    end

    COLUMN_LABELS = {
      'file name'          => :file_name,
      'title'              => :title,
      'mods xml file path' => :xml_path,
      'sequence'           => :sequence_raw,
      'last item'          => :last_item_raw
    }.freeze

    # Columns normalized to stripped strings; Sequence / Last Item stay raw
    # for Row's typed coercion.
    STRING_ATTRS = %i[file_name title xml_path].freeze

    def initialize(path)
      @sheet = Roo::Excelx.new(path)
    end

    def rows
      raise EmptyError, 'The manifest spreadsheet is empty.' if @sheet.first_row.nil?

      index = column_index_map(@sheet.row(@sheet.first_row))
      raise HeaderError, header_error_message if index.empty?

      ((@sheet.first_row + 1)..@sheet.last_row).filter_map do |i|
        cells = @sheet.row(i)
        next if cells.all?(&:blank?)

        build_row(index, cells)
      end
    end

    private

      def column_index_map(header_cells)
        map = {}
        header_cells.each_with_index do |label, idx|
          next if label.blank?

          attr = COLUMN_LABELS[label.to_s.downcase.strip]
          map[attr] ||= idx if attr
        end
        map
      end

      def build_row(index, cells)
        attrs = index.to_h do |attr, idx|
          value = cells[idx]
          [attr, STRING_ATTRS.include?(attr) ? value.to_s.strip.presence : value]
        end
        Row.new(**attrs)
      end

      def header_error_message
        'The manifest has no recognizable header row ' \
          '(expected columns such as "File Name", "Sequence", and "MODS XML File Path").'
      end
  end
end
