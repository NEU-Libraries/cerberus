# frozen_string_literal: true

require 'rack/timeout/base'

# A wall-clock deadline on a request, except on the routes that stream.
#
# Rack::Timeout counts wall time, so one global `service_timeout` low enough to
# protect a page would kill a large download mid-flight: a multi-gigabyte video
# or a bulk zip legitimately runs for many minutes. This wraps Rack::Timeout
# rather than replacing it — an exempt path goes straight to the app with no
# timer, everything else gets the deadline.
#
# Matching is on the path because middleware runs before routing, so there is no
# controller to ask yet. That makes the list something to keep in step with the
# streaming controllers, and spec/lib/request_deadline_spec.rb is what keeps it
# honest: it walks the route set for ActionController::Live and fails naming any
# route this does not exempt.
#
# Read Rack::Timeout's own warning before raising the deadline's importance: it
# interrupts with Thread#raise, which can leave the app in an inconsistent state
# and does not guarantee an in-flight transaction is rolled back. It is the
# backstop beneath the per-client deadlines, not a substitute for them.
class RequestDeadline
  EXEMPT = [
    %r{\A/downloads/},
    %r{\A/media/},
    %r{\A/download_queue/archive},
    %r{\A/collections/[^/]+/export},
    %r{\A/sets/[^/]+/download},
    %r{\A/sets/[^/]+/export},
    %r{\A/admin/files/[^/]+/versions/[^/]+/content}
  ].freeze

  # @param path [String] the request path (`PATH_INFO`).
  # @return [Boolean] true when the path streams and must not be interrupted.
  def self.exempt?(path)
    EXEMPT.any? { |pattern| pattern.match?(path) }
  end

  def initialize(app, service_timeout:)
    @app = app
    @guarded = Rack::Timeout.new(app, service_timeout: service_timeout)
  end

  def call(env)
    return @app.call(env) if self.class.exempt?(env['PATH_INFO'].to_s)

    @guarded.call(env)
  end
end
