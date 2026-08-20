# frozen_string_literal: true

# The scaffolding both Set bulk sweeps share: resolve the Set, walk the Works it
# denotes, apply a per-Work change, and tell whoever asked for it what happened.
#
# The two sweeps differ only in the change they make to each Work and the words
# they report it in. Everything else — how a Set is re-read at run time, which
# errors abort and which are collected, how a truncated walk is disclosed — is
# the same, and needs to stay the same: both are operator actions over content
# someone else deposited, and both are judged by whether a partial run is
# obvious afterwards.
module SetSweep
  extend ActiveSupport::Concern

  # What one sweep did. `counts` tallies outcomes by the symbol the per-Work step
  # returns, so a sweep names its own outcomes without this concern knowing them.
  # Named `counts` rather than `tally` because a Struct is Enumerable and would
  # shadow Enumerable#tally.
  Outcome = Struct.new(:counts, :failures, :truncated, keyword_init: true) do
    def problems?
      failures.any? || truncated
    end
  end

  private

    # Walk the Set's Works, yielding each NOID to the caller's per-Work step.
    #
    # The step returns a symbol naming what it did, which is counted. Anything it
    # raises is collected against that Work and the walk continues — one
    # unreachable Work must not abandon the rest of the sweep. A stale-lock
    # conflict is the exception: it escapes to the job's retry_on, because it is
    # transient and re-running an idempotent sweep only re-skips what already
    # succeeded.
    #
    # @param set_noid [String]
    # @param nuid [String, nil] the acting operator, scoping the walk.
    # @yieldparam noid [String]
    # @yieldreturn [Symbol]
    # @return [Outcome]
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

    # The trailing lines every sweep report ends with: the truncation disclosure,
    # the named failures, and a link back to the Set.
    #
    # Failures are named rather than counted because in both sweeps a Work that
    # did not change is a Work still carrying the access the operator meant to
    # take away — the one outcome they must not have to discover for themselves.
    #
    # @param failures_lead [String] how this sweep describes what a failure left
    #   behind, which is the only part that differs.
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
