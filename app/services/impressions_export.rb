# frozen_string_literal: true

require 'csv'
require 'caxlsx'

# Renders an ImpressionsReport's top-N tables as CSV or Excel — the downloadable
# artifact behind the quarterly DRS Statistics Report. One flat table for CSV
# (Kind/NOID/Title + per-action columns + total); one sheet per table for Excel.
#
# `kind` picks which of the dashboard's two tables to render, so the CSV/Excel
# links sitting under a table export that table. A nil kind keeps both, which is
# what the quarterly report wants and what a link with no kind param still gets.
class ImpressionsExport
  HEADERS = ['Kind', 'NOID', 'Title', *ImpressionsReport::ACTIONS.map(&:capitalize), 'Total'].freeze

  # Table key => [sheet name, the Kind cell, the report reader]. Ordered, because
  # a both-kinds CSV concatenates in this order and Excel adds sheets in it.
  TABLES = {
    'work'      => ['Top files',       'Work',      :top_works],
    'container' => ['Top collections', 'Container', :top_containers]
  }.freeze

  KINDS = TABLES.keys.freeze

  # An unrecognised kind exports both rather than raising: the param reaches this
  # from a URL a curator can edit, and a silently-empty spreadsheet would be a
  # worse answer than the full one.
  def initialize(report, kind: nil)
    @report = report
    @kinds  = KINDS.include?(kind.to_s) ? [kind.to_s] : KINDS
  end

  def csv
    CSV.generate do |out|
      out << HEADERS
      @kinds.each { |kind| rows_for(kind).each { |row| out << row } }
    end
  end

  def xlsx
    package = Axlsx::Package.new
    @kinds.each { |kind| add_sheet(package, kind) }
    package.to_stream.read
  end

  # Filename slug for what this export actually covers — 'files', 'collections',
  # or nothing extra when it covers both.
  def slug
    return nil if @kinds.size > 1

    @kinds.first == 'work' ? 'files' : 'collections'
  end

  private

    def rows_for(kind)
      _name, label, reader = TABLES.fetch(kind)
      @report.public_send(reader).map do |entry|
        [label, entry[:noid], title(entry),
         *ImpressionsReport::ACTIONS.map { |action| entry[:counts][action] }, entry[:total]]
      end
    end

    def add_sheet(package, kind)
      name, = TABLES.fetch(kind)
      package.workbook.add_worksheet(name:) do |sheet|
        sheet.add_row HEADERS
        rows_for(kind).each { |row| sheet.add_row row }
      end
    end

    def title(entry)
      doc = entry[:doc]
      (doc && Array(doc[ImpressionsReport::TITLE_FIELD]).first).presence || entry[:noid]
    end
end
