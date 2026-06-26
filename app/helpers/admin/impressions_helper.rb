# frozen_string_literal: true

module Admin
  # View helpers for the usage-analytics dashboard: chartkick-ready datasets,
  # the segment toggle, and export links. Kept out of the controller (thin) and
  # the report (data-only).
  module ImpressionsHelper
    # Per-action series as a chartkick multi-series array (string day keys).
    def usage_timeseries(report)
      ImpressionsReport::ACTIONS.map do |action|
        { name: action.capitalize, data: report.series(action).transform_keys(&:to_s) }
      end
    end

    def usage_visitors_series(report)
      [{ name: 'Unique visitors', data: report.unique_visitors_series.transform_keys(&:to_s) }]
    end

    # A segment-toggle option that preserves the current date range.
    def usage_segment_link(report, segment, label)
      active = report.segment.to_s == segment
      link_to label,
              admin_impressions_path(request.query_parameters.merge(segment:)),
              class: "usage-toggle__option #{'is-active' if active}".strip,
              'aria-pressed' => active.to_s
    end

    # Range/segment params for the export links (format passed separately).
    def usage_export_params(report)
      { from: report.range.begin, to: report.range.end, segment: report.segment }
    end
  end
end
