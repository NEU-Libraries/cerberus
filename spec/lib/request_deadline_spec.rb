# frozen_string_literal: true

require 'rails_helper'

# The rule this file exists to keep: **every route that streams is exempt from
# the request deadline, and everything else is not.**
#
# Rack::Timeout counts wall time and interrupts with Thread#raise, so a deadline
# on a streaming route truncates the download it fires during — a
# multi-gigabyte video or a bulk zip legitimately outlives any page-sized
# budget. The middleware has to decide from the path alone, because it runs
# before routing, so its list cannot ask a controller whether it streams.
#
# This derives the answer the middleware cannot: it walks the route set for
# ActionController::Live and fails naming any route the exemption misses. Adding
# a streaming controller therefore fails here rather than silently truncating
# its downloads in production.
describe RequestDeadline do
  describe 'the exemption list' do
    let(:streaming_routes) do
      Rails.application.eager_load!
      Rails.application.routes.routes.filter_map do |route|
        controller = route.defaults[:controller]
        next unless controller

        klass = "#{controller.camelize}Controller".safe_constantize
        next unless klass&.include?(ActionController::Live)

        route.path.spec.to_s.sub(/\(\.:format\)\z/, '')
      end.uniq
    end

    it 'covers every route whose controller streams' do
      # The spec path is a template ("/sets/:id/export"); the middleware sees a
      # real one, so substitute a plausible segment for each dynamic part.
      missed = streaming_routes.reject do |template|
        described_class.exempt?(template.gsub(/:[a-z_]+/, 'abc123'))
      end

      expect(missed).to be_empty,
                        "these streaming routes would be interrupted mid-download: #{missed.join(', ')}"
    end

    it 'finds some streaming routes to check, so a resolution failure cannot pass silently' do
      expect(streaming_routes.size).to be >= 5
    end

    it 'does not exempt an ordinary page' do
      expect(described_class.exempt?('/works/9zw3s1h')).to be false
      expect(described_class.exempt?('/catalog')).to be false
    end
  end

  describe 'the middleware stack' do
    it 'mounts the deadline ahead of the rest of the stack' do
      expect(Rails.application.config.middleware.middlewares.first.name).to eq('RequestDeadline')
    end

    # The gem's own entry point installs a railtie that wraps every request. If
    # that ever loads, the streaming exemption is bypassed and downloads truncate.
    it 'does not also mount Rack::Timeout globally' do
      names = Rails.application.config.middleware.middlewares.map(&:name)
      expect(names).not_to include('Rack::Timeout')
    end
  end
end
