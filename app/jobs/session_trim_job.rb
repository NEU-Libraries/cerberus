# frozen_string_literal: true

# Sweeps idle DB-backed sessions older than the TTL. ActiveRecord::SessionStore
# never expires rows itself, so without this the `sessions` table grows
# unbounded. Scheduled hourly in config/recurring.yml, mirroring
# clear_solid_queue_finished_jobs. Deletes in batches so a large first sweep
# doesn't hold a long lock.
class SessionTrimJob < ApplicationJob
  queue_as :background

  TTL = 2.weeks
  BATCH_SIZE = 1_000

  def perform(ttl: TTL, batch_size: BATCH_SIZE)
    ActiveRecord::SessionStore::Session
      .where(updated_at: ...ttl.ago)
      .in_batches(of: batch_size)
      .delete_all
  end
end
