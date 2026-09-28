# frozen_string_literal: true

# Asks Atlas to record the embargoes that have lapsed. An embargo lapsing is not
# a write, so nothing else would put a "release_embargo" row in a Work's history.
# Atlas owns the window, the dating and the idempotency; this job only supplies
# the schedule, in config/recurring.yml.
class EmbargoReleaseJob < ApplicationJob
  queue_as :background

  def perform
    released = AtlasRb::System.release_embargoes
    Rails.logger.info("EmbargoReleaseJob: recorded #{released.size} lapsed embargo(es)")
  rescue AtlasRb::ReadOnlyModeError
    # Atlas looks back seven days, so the next night's run records what this one
    # missed. Retrying would only keep knocking through the maintenance window.
    Rails.logger.info('EmbargoReleaseJob: Atlas is read-only; skipped until the next run')
  end
end
