# frozen_string_literal: true

# The scaffolding both Set bulk sweeps share: resolve the Set, walk the Works it
# denotes, apply a per-Work change, and report what happened. See docs/sets.md.
module SetSweep
  extend ActiveSupport::Concern

  # Named `counts` and not `tally`: a Struct is Enumerable, so `tally` here
  # would shadow Enumerable#tally.
  Outcome = Struct.new(:counts, :failures, :truncated, keyword_init: true) do
    def problems?
      failures.any? || truncated
    end
  end

  private

    # Anything the step raises is collected against that Work and the walk
    # continues; a stale-lock conflict is the exception and escapes to the job's
    # retry_on, since re-running an idempotent sweep only re-skips successes.
    def sweep_set(set_noid:, nuid:, &step)
      contents = SetWorkEnumerator.new(set_noid: set_noid, nuid: nuid).call
      counts = Hash.new(0)
      failures = []

      contents.noids.each do |noid|
        counts[step.call(noid)] += 1
      rescue AtlasRb::StaleResourceError
        raise
      rescue AtlasRb::Error, Faraday::Error => e
        failures << "Work #{noid}: #{e.message}"
      end

      Outcome.new(counts: counts, failures: failures, truncated: contents.truncated)
    end

    def sweep_report_tail(set_noid, outcome, failures_lead)
      lines = []
      if outcome.truncated
        lines += ['', "This set denotes more than #{SetWorkEnumerator::MAX_WORKS} works, so only the " \
                      'first were changed. Run it again to continue.']
      end
      lines += ['', failures_lead, *outcome.failures] if outcome.failures.any?
      # A path, not a _url: a job has no request to take a host from, and the
      # inbox renders these in-app anyway.
      lines + ['', Rails.application.routes.url_helpers.set_path(set_noid)]
    end
end
