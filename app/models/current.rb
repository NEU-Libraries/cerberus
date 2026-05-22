# frozen_string_literal: true

# Ambient per-request context. Set once at the controller boundary and
# read by every AtlasRb::* call site (controllers, jobs, rake tasks).
#
# Rails 7's ActiveJob ↔ CurrentAttributes integration captures attribute
# values at enqueue and restores them on perform, so jobs and their
# downstream child enqueues see the same nuid without explicit threading.
class Current < ActiveSupport::CurrentAttributes
  attribute :nuid
end
