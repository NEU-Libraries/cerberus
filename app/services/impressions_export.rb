# frozen_string_literal: true

require 'csv'
require 'caxlsx'

# Renders an ImpressionsReport's top-N tables as CSV or Excel — the downloadable
# artifact behind the quarterly DRS Statistics Report. One flat table for CSV
# (Kind/NOID/Title + per-action columns + total); two sheets for Excel.
class ImpressionsExport
  HEADERS = ['Kind', 'NOID', 'Title', *ImpressionsReport::ACTIONS.map(&:capitalize), 'Total'].freeze

  def initialize(report)
    @report = report
  end

  def csv
    CSV.generate do |out|
      out << HEADERS
      table_rows.each { |row| out << row }
    end
  end

  def xlsx
    package = Axlsx::Package.new
    add_sheet(package, 'Top files', @report.top_works, 'Work')
    add_sheet(package, 'Top collections', @report.top_containers, 'Container')
    package.to_stream.read
  end

  private

    def table_rows
      rows_for(@report.top_works, 'Work') + rows_for(@report.top_containers, 'Container')
    end

    def rows_for(entries, kind)
      entries.map do |entry|
        [kind, entry[:noid], title(entry),
         *ImpressionsReport::ACTIONS.map { |action| entry[:counts][action] }, entry[:total]]
      end
    end

    def add_sheet(package, name, entries, kind)
      package.workbook.add_worksheet(name:) do |sheet|
        sheet.add_row HEADERS
        rows_for(entries, kind).each { |row| sheet.add_row row }
      end
    end

    def title(entry)
      doc = entry[:doc]
      (doc && Array(doc[ImpressionsReport::TITLE_FIELD]).first).presence || entry[:noid]
    end
end
