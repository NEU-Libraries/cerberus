# frozen_string_literal: true

# The read-only maintenance window, as Cerberus sees it.
#
# Atlas owns the flag and enforces it. This class is only the read side — a
# courtesy layer over Atlas's floor, never the boundary. Reads are cached for
# config.x.cerberus.maintenance_ttl. See docs/maintenance.md.
class MaintenanceMode
  CACHE_KEY = 'maintenance_mode/window'

  class << self
    # @return [Boolean] whether the repository is refusing writes.
    def read_only? = window.read_only.present?

    # @return [String, nil] the operator's note for the banner.
    def message = window.message.presence

    # @return [Integer, nil] seconds Atlas asks a refused caller to wait.
    delegate :retry_after, to: :window

    # @return [AtlasRb::Mash] read_only, source, since, message, retry_after
    def window
      Rails.cache.fetch(CACHE_KEY, expires_in: ttl) { fetch_window }
    end

    # @return [AtlasRb::Mash] the state Atlas reports after the write
    def open!(message: nil, retry_after: nil, source: 'operator')
      write(read_only: true, source: source, message: message, retry_after: retry_after)
    end

    # Atlas refuses a `deploy` close of an operator-opened window with 200 and
    # the UNCHANGED state, not an error — a caller that needs to know whether
    # the close landed must read `read_only` off the return value.
    #
    # @return [AtlasRb::Mash] the state Atlas reports after the write
    def close!(source: 'operator') = write(read_only: false, source: source)

    # Called after a write so the flipping request sees its own effect rather
    # than waiting out the TTL.
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

      # The two failure modes need OPPOSITE answers: a transport failure holds
      # the window, an unreadable HTTP response assumes none. Do not make the
      # second fail closed — it would put the whole site into maintenance mode
      # on any Atlas hiccup and block deploying Cerberus ahead of Atlas.
      # See docs/maintenance.md.
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

      # The read sits on Atlas's authenticated read floor, so a rake task or job
      # with no Current.nuid falls back to the guest identity.
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
