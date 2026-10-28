# frozen_string_literal: true

# Applies a Set's Sentinel to every Work the Set denotes: the Work's own
# visibility and groups first, then its derivative tiers. See docs/sets.md for
# the refused Works and for undoing a sweep from its ledger entry.
class SetSentinelApplyJob < ApplicationJob
  include SetSweep

  queue_as :default

  # A lock conflict is retried on the one Work, not through retry_on: a re-run
  # finds the changed Works already matching, and its ledger entry would leave
  # them out.
  LOCK_ATTEMPTS = 3

  def perform(set_noid:)
    actor = Current.nuid
    compilation = AtlasRb::Compilation.find(set_noid)
    return if compilation.nil?

    # Re-read rather than carried through the queue, so a policy edited between
    # the click and the run is the one that gets applied.
    sentinel = Sentinel.find_by(target_id: set_noid)
    return if sentinel.nil?

    @changed = []
    @refused = []
    outcome = sweep_set(set_noid: set_noid, nuid: actor) { |noid| apply_to(sentinel, noid, actor) }

    report(actor: actor, set_noid: set_noid, title: compilation['title'], outcome: outcome)
  end

  private

    def apply_to(sentinel, noid, actor, attempt: 1)
      applied = sentinel.apply_to(noid, nuid: actor)
      return :skipped if applied.nil?
      return :applied unless applied.acl_changed

      @changed << { 'noid' => noid, 'read_before' => applied.read_before, 'edit_before' => applied.edit_before }
      :changed
    # Named apart from other failures: the remedy is widening the collection,
    # and a retry would be refused the same way.
    rescue AtlasRb::PermissionsError => e
      raise unless e.code == 'visibility_exceeds_parent'

      @refused << noid
      :refused
    rescue AtlasRb::StaleResourceError => e
      return apply_to(sentinel, noid, actor, attempt: attempt + 1) if attempt < LOCK_ATTEMPTS

      # A plain error, so SetSweep names it as this Work's failure rather than
      # handing it on as a lock conflict to retry the whole job.
      raise AtlasRb::Error, e.message
    end

    def report(actor:, set_noid:, title:, outcome:)
      problems = outcome.problems? || @refused.any?
      CompletionNotice.deliver(
        kind:         'set_sentinel_apply',
        to_nuid:      actor,
        subject:      "Set Sentinel sweep #{problems ? 'finished with problems' : 'finished'}",
        body:         body_for(set_noid, title, outcome),
        subject_noid: set_noid,
        payload:      { title: title, changed_count: outcome.counts[:changed], applied: outcome.counts[:applied],
                        skipped: outcome.counts[:skipped], refused: @refused, truncated: outcome.truncated,
                        failures: outcome.failures, changed: @changed }
      )
    end

    def body_for(set_noid, title, outcome)
      counts = outcome.counts
      done = counts[:changed] + counts[:applied]
      lines = ["“#{title}”: Sentinel applied to #{done} work#{'s' unless done == 1}."]
      lines << "#{counts[:changed]} had their visibility or groups changed." if counts[:changed].positive?
      lines << "#{counts[:skipped]} could not be read and were skipped." if counts[:skipped].positive?
      lines += refused_lines
      tail = sweep_report_tail(set_noid, outcome, 'These were not changed and keep their previous access:')
      (lines + tail).join("\n")
    end

    def refused_lines
      return [] if @refused.empty?

      ['', "#{@refused.size} could not be made more visible than the collection they are in. " \
           'Open each collection to widen it first:', *@refused.map { |noid| "Work #{noid}" }]
    end
end
