# frozen_string_literal: true

# The read-only maintenance window, as Cerberus sees it.
#
# Atlas owns the flag and enforces it: while the window is open, every write it
# receives is refused with a 503 carrying `error: "read_only_mode"`, which
# atlas_rb raises as AtlasRb::ReadOnlyModeError. This class is the read side —
# what Cerberus consults to render its banner and to refuse a write before it
# leaves the app. It is a courtesy layer over Atlas's floor, never the boundary.
#
# Reads are cached for config.x.cerberus.maintenance_ttl. Where the cache store
# is a null store (test, and any environment with caching off) that degrades to
# one call per request, which is correct but chatty; in test it also keeps one
# example's window from leaking into the next.
class MaintenanceMode
  CACHE_KEY = 'maintenance_mode/window'

  class << self
    # @return [Boolean] whether the repository is refusing writes.
    def read_only? = window.read_only.present?

    # @return [String, nil] the operator's note for the banner.
    def message = window.message.presence

    # @return [Integer, nil] seconds Atlas asks a refused caller to wait.
    delegate :retry_after, to: :window

    # The window's state, cached.
    #
    # @return [AtlasRb::Mash] read_only, source, since, message, retry_after
    def window
      Rails.cache.fetch(CACHE_KEY, expires_in: ttl) { fetch_window }
    end

    # Open the window.
    #
    # @param source ['operator', 'deploy'] which door is acting. Atlas records
    #   it and enforces one rule with it — see #close!.
    # @return [AtlasRb::Mash] the state Atlas reports after the write
    def open!(message: nil, retry_after: nil, source: 'operator')
      write(read_only: true, source: source, message: message, retry_after: retry_after)
    end

    # Close the window.
    #
    # A `deploy` close is refused when an operator opened the window, so a
    # deploy that finishes cannot end a window a human opened by hand. Atlas
    # answers that refusal with 200 and the *unchanged* state rather than an
    # error, so a caller that needs to know must read `read_only` off the
    # return value. An operator close clears either.
    #
    # @return [AtlasRb::Mash] the state Atlas reports after the write
    def close!(source: 'operator') = write(read_only: false, source: source)

    # Drop the cached state. Called after a write so the flipping request sees
    # its own effect rather than waiting out the TTL.
    def reset_cache! = Rails.cache.delete(CACHE_KEY)

    private

      def write(read_only:, source:, message: nil, retry_after: nil)
        AtlasRb::Maintenance.write(
          read_only:   read_only,
          source:      source,
          message:     message,
          retry_after: retry_after
        )
      ensure
        reset_cache!
      end

      # Two failure modes, and they need opposite answers.
      #
      # A TRANSPORT failure — nothing answered at all — happens while Atlas is
      # being replaced, which is exactly when a window is likely to be open and
      # when Cerberus could not render a page anyway. Hold the window.
      #
      # An HTTP response we cannot read means Atlas is up and talking but told
      # us nothing about a window: most often it is a build older than the
      # endpoint. Treat that as no window. Failing closed here would be far
      # worse than the ugly error a refused write would produce — it would put
      # the whole site into maintenance mode on any Atlas hiccup, and it would
      # make Cerberus impossible to deploy ahead of Atlas.
      #
      # Atlas is the boundary either way: a write during a window it did not
      # tell us about is still refused, and MaintenanceGate's
      # AtlasRb::ReadOnlyModeError rescue turns that into the same page.
      def fetch_window
        AtlasRb::Maintenance.read(nuid: acting_nuid)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        Rails.logger.error("[maintenance] Atlas did not answer, holding the window: #{e.class}: #{e.message}")
        unreachable_window
      rescue StandardError => e
        Rails.logger.error(
          "[maintenance] Atlas answered but not with a window, assuming none: #{e.class}: #{e.message}"
        )
        no_window
      end

      # Current.nuid is set per request; a rake task or job has none, so fall
      # back to the guest identity — the read sits on Atlas's authenticated
      # read floor, which the guest fixture satisfies.
      def acting_nuid = Current.nuid.presence || Rails.application.config.x.cerberus.guest_nuid

      def no_window = AtlasRb::Mash.new('read_only' => false)

      def unreachable_window
        AtlasRb::Mash.new(
          'read_only'   => true,
          'source'      => nil,
          'since'       => nil,
          'message'     => 'The repository is temporarily unavailable.',
          'retry_after' => 60
        )
      end

      def ttl = Rails.application.config.x.cerberus.maintenance_ttl
  end
end
