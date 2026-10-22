# frozen_string_literal: true

# How long people wait for the pages they actually read, and how much of that
# is waiting on Atlas, for the admin health page. See docs/outages.md.
module PageLatency
  # A fixed list rather than every route: ranked by traffic, the admin pages and
  # redirects would crowd out the pages a reader waits on.
  PAGES = {
    'works#show'       => 'Work page',
    'collections#show' => 'Collection page',
    'communities#show' => 'Community page',
    'catalog#index'    => 'Search results',
    'pages#home'       => 'Home'
  }.freeze

  Row = Data.define(:label, :views, :usual_ms, :slow_ms, :mean_ms, :atlas_mean_ms) do
    # The rest of the mean, after waiting on Atlas: building the page, searching
    # and everything else. Means add up, which percentiles do not.
    def page_mean_ms = [mean_ms - atlas_mean_ms.to_i, 0].max
  end

  module_function

  def histogram(route) = LatencyHistogram.new("page:#{route}")

  # Successful GETs only: an error page's time says nothing about how long the
  # page itself takes.
  def record(event)
    payload = event.payload
    route = "#{payload[:controller].to_s.underscore.delete_suffix('_controller')}##{payload[:action]}"
    return unless PAGES.key?(route) && payload[:method] == 'GET' && payload[:status].to_i.between?(200, 399)

    atlas_ms = Current.request_timing&.atlas_elapsed_ms || 0
    histogram(route).record(event.duration, sums: { atlas_ms: atlas_ms })
  end

  # nil when Redis did not answer; pages with no views in the window are left out.
  def rows
    summaries = PAGES.to_h { |route, label| [label, histogram(route).summary] }
    return nil if summaries.values.any?(&:nil?)

    summaries.filter_map do |label, summary|
      next if summary.calls.zero?

      Row.new(label: label, views: summary.calls, usual_ms: summary.p50_ms, slow_ms: summary.p95_ms,
              mean_ms: summary.mean_ms, atlas_mean_ms: summary.extra_means[:atlas_ms])
    end
  end
end
