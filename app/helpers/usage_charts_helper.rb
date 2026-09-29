# frozen_string_literal: true

# Chartkick-ready dataset formatting for an ImpressionsReport — pure
# ImpressionsReport-to-JSON transforms, nothing admin-page-specific, so this
# lives outside Admin::ImpressionsHelper: the /admin dashboard uses it for
# its own (usually unscoped) report, and the Collection/Community edit
# pages' Analytics tab reuses it for a report scoped to that one container
# (see CollectionsController/CommunitiesController#edit).
module UsageChartsHelper
  LABEL_FORMAT = '%b %-d'

  # One colour per ImpressionsReport action, in ACTIONS order; the stat ledger's
  # accents in _admin_impressions.scss use the same three tones.
  SERIES_COLORS = { 'view' => '#2666a6', 'download' => '#18bc9c', 'stream' => '#c46410' }.freeze

  # Per-action series as a chartkick multi-series array.
  def usage_timeseries(report, actions: ImpressionsReport::ACTIONS)
    actions.map do |action|
      { name: action.capitalize, data: dense_series(report.range, report.series(action)) }
    end
  end

  def usage_series_colors(actions: ImpressionsReport::ACTIONS)
    actions.map { |action| SERIES_COLORS.fetch(action) }
  end

  def usage_visitors_series(report)
    [{ name: 'Unique visitors', data: dense_series(report.range, report.unique_visitors_series) }]
  end

  # Divided by every day in the range, not by the days that have a row: the
  # series is sparse, and skipping its zero days would inflate the average.
  # One decimal, so a quiet collection does not read as zero.
  def usage_daily_visitor_average(report)
    days = report.range.count
    return 0 if days.zero?

    (report.unique_visitors_series.values.sum.to_f / days).round(1)
  end

  def usage_empty_message(report)
    from, to = [report.range.begin, report.range.end].map { |day| day.strftime('%B %-d, %Y') }
    "No activity between #{from} and #{to}. Usage statistics are refreshed daily."
  end

  private

    # Every day in the range, zero-filled. The underlying rollups carry no row
    # for a zero-activity day, and that sparseness is wrong for a chart in two
    # ways: a line interpolates straight through the gaps, and a column chart's
    # categorical x-axis unions each series' own labels in first-seen order, so
    # a day only one series has (a download with no views) lands *after* every
    # day the first series had — the axis stops being chronological. Filling
    # every day gives all series identical, sorted keys.
    #
    # @param range [Range<Date>]
    # @param series [Hash{Date => Integer}]
    # @return [Hash{String => Integer}] short human day labels (the categorical
    #   axis renders the key verbatim), chronological.
    def dense_series(range, series)
      range.to_a.index_with { |day| series[day].to_i }
           .transform_keys { |day| day.strftime(LABEL_FORMAT) }
    end
end
