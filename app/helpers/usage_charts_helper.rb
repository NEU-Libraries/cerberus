# frozen_string_literal: true

# Chartkick-ready dataset formatting for an ImpressionsReport — pure
# ImpressionsReport-to-JSON transforms, nothing admin-page-specific, so this
# lives outside Admin::ImpressionsHelper: the /admin dashboard uses it for
# its own (usually unscoped) report, and the Collection/Community edit
# pages' Analytics tab reuses it for a report scoped to that one container
# (see CollectionsController/CommunitiesController#edit).
module UsageChartsHelper
  # Per-action series as a chartkick multi-series array (string day keys).
  def usage_timeseries(report)
    ImpressionsReport::ACTIONS.map do |action|
      { name: action.capitalize, data: report.series(action).transform_keys(&:to_s) }
    end
  end

  def usage_visitors_series(report)
    [{ name: 'Unique visitors', data: report.unique_visitors_series.transform_keys(&:to_s) }]
  end
end
