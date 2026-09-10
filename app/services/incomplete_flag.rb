# frozen_string_literal: true

# The one place Cerberus writes Atlas's `incomplete` state. See docs/deposit.md.
class IncompleteFlag
  # From a give-up handler pass `nuid: job.current_nuid`: the handler runs
  # OUTSIDE `perform`, so Current.nuid is gone and Atlas refuses the write —
  # which the rescue below then hides. Never raise into a caller.
  def self.set(work_id, reason:, nuid: nil)
    AtlasRb::Work.mark_incomplete(work_id, reason: reason, nuid: nuid)
  rescue AtlasRb::Error, Faraday::Error, JSON::ParserError => e
    Rails.logger.error("[incomplete] could not flag work #{work_id} as #{reason}: #{e.class} #{e.message}")
  end

  # No `nuid:` here, deliberately: this runs inside `perform`, and a perform_now
  # child carries none of its own — it inherits the caller's through Current.
  def self.clear(work_id)
    AtlasRb::Work.clear_incomplete(work_id)
  rescue AtlasRb::Error, Faraday::Error, JSON::ParserError => e
    Rails.logger.error("[incomplete] could not clear the flag on work #{work_id}: #{e.class} #{e.message}")
  end
end
