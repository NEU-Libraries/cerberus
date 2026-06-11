# frozen_string_literal: true

require 'roo'

module XmlLoader
  # Parses a loader manifest.xlsx into normalized rows.
  #
  # Header matching is case-insensitive and whitespace-tolerant, mirroring v1's
  # find_in_row so manifests authored against the v1 template still load. Only
  # the columns this loader cares about are mapped; everything else is ignored.
  #
  # Structural problems raise (EmptyError / HeaderError) so the caller — the
  # preview pass and the unzip job — can surface a precise reason to the
  # librarian instead of silently producing zero rows.
  class Manifest
    class EmptyError < StandardError; end
    class HeaderError < StandardError; end

    # Per-row view of the columns the XML loader consumes. `update?` /
    # `create?` encode v1's edit-vs-create determination: a row with an
    # identifier (NOID) updates an existing Work; a row with only a file name
    # creates a new one.
    Row = Struct.new(:identifier, :xml_path, :file_name, :embargoed, :embargo_date, keyword_init: true) do
      def update?
        identifier.present?
      end

      def create?
        identifier.blank? && file_name.present?
      end

      def embargoed?
        embargoed.to_s.strip.casecmp?('true')
      end
    end

    # Header label (downcased) → Row attribute. `PIDs` is v1's column name for
    # what is now a v2 NOID; the noid aliases let v2-native manifests use the
    # clearer header. First matching column wins.
    COLUMN_LABELS = {
      'pids'               => :identifier,
      'pid'                => :identifier,
      'noid'               => :identifier,
      'noids'              => :identifier,
      'mods xml file path' => :xml_path,
      'file name'          => :file_name,
      'embargoed?'         => :embargoed,
      'embargo date'       => :embargo_date
    }.freeze

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
        attrs = index.transform_values { |idx| cells[idx].to_s.strip.presence }
        Row.new(**attrs)
      end

      def header_error_message
        'The manifest has no recognizable header row ' \
          '(expected columns such as "PIDs" and "MODS XML File Path").'
      end
  end
end
