# frozen_string_literal: true

# Applies a Set's Sentinel — its per-tier derivative-access policy — to every
# Work the Set denotes.
#
# This is the proactive sweep over content that already exists, and it is the
# counterpart to the Collection Sentinel rather than a duplicate of it: a
# Collection's Sentinel stamps *new* deposits at create and is deliberately not
# retroactive, so nothing else fixes the renditions of Works already in place.
# Authoring or editing a Collection Sentinel still triggers no sweep.
#
# Each tier is clamped against the Work it is written to. Atlas refuses a tier
# naming a group the Work does not grant (`tier_exceeds_resource`), and on a
# private Work the only legal value is the empty list — so applying a policy as
# authored would fail on exactly the Works most in need of a gate. Clamping is
# also the honest reading of the policy: a tier can never widen a Work, only
# narrow it. A tier sharing nobody with its Work clamps to `[]`, withheld from
# everyone, which is the right direction for a gate whose purpose is to withhold.
#
# Re-running is safe: the per-Work write is an idempotent PATCH, so a retry after
# a partial run rewrites what it already wrote and finishes the rest.
class SetSentinelApplyJob < ApplicationJob
  include SetSweep

  queue_as :default

  retry_on AtlasRb::StaleResourceError, wait: :polynomially_longer, attempts: 5

  # @param set_noid [String] the Compilation's NOID, which is also the Sentinel's
  #   target_id.
  def perform(set_noid:)
    actor = Current.nuid
    compilation = AtlasRb::Compilation.find(set_noid)
    return if compilation.nil?

    # Re-read rather than carry the policy through the queue, so a policy edited
    # between the click and the run is the one that gets applied.
    sentinel = Sentinel.find_by(target_id: set_noid)
    return if sentinel.nil?

    outcome = sweep_set(set_noid: set_noid, nuid: actor) { |noid| apply_to(sentinel, noid, actor) }

    report(actor: actor, set_noid: set_noid, title: compilation['title'], outcome: outcome)
  end

  private

    # @return [Symbol] :applied or :skipped
    def apply_to(sentinel, noid, actor)
      current = AtlasRb::Resource.permissions(noid)
      return :skipped if current.nil?

      # A whole-object replace is the intent, not an oversight: the Sentinel is
      # the authority on this Set's renditions, and a tier it does not name is
      # meant to ride the Work rather than keep an older restriction. Atlas reads
      # an absent key as exactly that.
      AtlasRb::Work.set_derivative_permissions(
        noid, policy: clamped_policy(sentinel, Array(current.read)), nuid: actor
      )
      :applied
    end

    # The authored policy narrowed to what each tier's Work can actually grant.
    def clamped_policy(sentinel, work_read)
      sentinel.tier_policy.transform_values do |groups|
        Permissions.audience_intersect(Array(groups), work_read)
      end
    end

    def report(actor:, set_noid:, title:, outcome:)
      state = outcome.problems? ? 'finished with problems' : 'finished'
      CompletionNotice.deliver(
        kind:         'set_sentinel_apply',
        to_nuid:      actor,
        subject:      "Derivative access sweep #{state}",
        body:         body_for(set_noid, title, outcome),
        subject_noid: set_noid,
        payload:      { title: title, applied: outcome.counts[:applied], skipped: outcome.counts[:skipped],
                        truncated: outcome.truncated, failures: outcome.failures }
      )
    end

    def body_for(set_noid, title, outcome)
      count = outcome.counts[:applied]
      lines = ["“#{title}”: derivative access applied to #{count} work#{'s' unless count == 1}."]
      lines << "#{outcome.counts[:skipped]} could not be read and were skipped." if outcome.counts[:skipped].positive?
      # A failure here leaves a rendition *wider* than intended, so the lead says
      # what the operator still has to deal with rather than merely that it failed.
      tail = sweep_report_tail(set_noid, outcome, 'These were not changed and keep their previous access:')
      (lines + tail).join("\n")
    end
end
