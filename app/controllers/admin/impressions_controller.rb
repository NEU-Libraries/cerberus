# frozen_string_literal: true

require 'csv'

module Admin
  # Repository-wide usage analytics over the derived impression rollups. Admin-
  # gated (inherits Admin::BaseController). Reads never touch raw rows — only the
  # human-counts / continuous-aggregate / container rollups (see ImpressionsReport).
  class ImpressionsController < BaseController
    XLSX_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

    def index
      @report = build_report
    end

    # CSV / Excel of the top-N tables (the quarterly-report artifact). Format
    # comes off the URL extension (.csv / .xlsx); no Mime registration needed.
    def export
      report = build_report
      if params[:format] == 'xlsx'
        send_data ImpressionsExport.new(report).xlsx, filename: filename(report, 'xlsx'), type: XLSX_TYPE
      else
        send_data ImpressionsExport.new(report).csv, filename: filename(report, 'csv'), type: 'text/csv'
      end
    end

    private

    def build_report
      ImpressionsReport.new(range: parsed_range, segment: params[:segment])
    end

    def parsed_range
      from = parse_date(params[:from]) || ImpressionsReport::DEFAULT_DAYS.days.ago.to_date
      to   = parse_date(params[:to]) || Date.current
      from..to
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def filename(report, ext)
      "impressions-#{report.range.begin}_#{report.range.end}-#{report.segment}.#{ext}"
    end
  end
end
