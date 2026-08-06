# frozen_string_literal: true

# Records that a Work's pipeline partly failed, and clears the record when it
# later succeeds. The one place Cerberus writes Atlas's `incomplete` state.
#
# What it is for: an enrichment job that exhausts its retries leaves a Work that
# is complete and readable but missing something — a PDF rendition, a poster
# frame, its thumbnails, its full text. Enrichment deliberately never fails a
# deposit, so before this the only trace was a line in the log, and nobody found
# out. The flag makes that visible without withholding the record.
#
# Deliberately NOT used for the two failures that already have a surface. A
# deposit whose confirmation never lands stays `in_progress`, which hides it and
# lists it under "Deposits to finish"; a loader row that fails is named in its
# load report, with the row and the reason. Flagging those as well would report
# the same fact twice, in a weaker way.
#
# The reason is a machine token, and the vocabulary is ours — Atlas stores it
# opaquely and does not validate it. IncompleteReasons maps tokens to what a
# person reads, with a fallback, so adding one here needs no view change.
class IncompleteFlag
  # `nuid:` is required from a give-up handler and must come from the job instance
  # the handler is passed (`job.current_nuid`). A handler runs OUTSIDE `perform`,
  # so ApplicationJob's around_perform has already unwound and the ambient
  # Current.nuid is gone — Atlas then has no principal to authenticate and refuses
  # the write with a ConfigurationError. That failure is caught below, so the
  # symptom is a flag that silently never appears.
  #
  # Never raise into a caller. Every call site is either a job's give-up handler
  # (already the end of a failure path) or the tail of a successful enrichment —
  # in both, an unreachable Atlas must not turn into a second failure. The log
  # line is the fallback the flag was invented to replace, so losing the write
  # costs visibility, not correctness.
  def self.set(work_id, reason:, nuid: nil)
    AtlasRb::Work.mark_incomplete(work_id, reason: reason, nuid: nuid)
  rescue AtlasRb::Error, Faraday::Error, JSON::ParserError => e
    Rails.logger.error("[incomplete] could not flag work #{work_id} as #{reason}: #{e.class} #{e.message}")
  end

  # Called on every successful enrichment run, not only after a flagged one:
  # asking Atlas whether the flag is set costs the same round trip as clearing
  # it, and the clear is idempotent. So a re-run that fixes a work — a replaced
  # file re-deriving its assets, say — heals the state on its own.
  #
  # No `nuid:` here, deliberately: this runs inside `perform`, where the ambient
  # Current.nuid is set and is the more correct source. A child job invoked with
  # perform_now carries no current_nuid of its own and inherits the caller's
  # through Current, so reading the instance attribute would lose it.
  def self.clear(work_id)
    AtlasRb::Work.clear_incomplete(work_id)
  rescue AtlasRb::Error, Faraday::Error, JSON::ParserError => e
    Rails.logger.error("[incomplete] could not clear the flag on work #{work_id}: #{e.class} #{e.message}")
  end
end
