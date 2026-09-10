# frozen_string_literal: true

# Strips `public` from the read ACL of every Work a Set denotes.
# See docs/people-and-routing.md and docs/sets.md.
#
# Group grants are kept: they grant nothing extra while an item is public, and
# they are what a later flip back to Private falls back to.
#
# Re-running is safe. A Work that is already private is skipped, so a retry
# after a partial run only finishes the remainder.
class SetPrivatizeJob < ApplicationJob
  include SetSweep

  queue_as :default

  # Atlas retries its own optimistic-lock conflicts and surfaces this only once
  # its budget is exhausted. Backing off and re-running is safe here precisely
  # because the sweep is idempotent.
  retry_on AtlasRb::StaleResourceError, wait: :polynomially_longer, attempts: 5

  def perform(set_noid:)
    actor = Current.nuid
    # Re-read rather than carried through the queue, so a Set renamed between the
    # click and the run reports under the name it has now.
    compilation = AtlasRb::Compilation.find(set_noid)
    return if compilation.nil?

    outcome = sweep_set(set_noid: set_noid, nuid: actor) { |noid| privatize(noid) }

    report(actor: actor, set_noid: set_noid, title: compilation['title'], outcome: outcome)
  end

  private

    def privatize(noid)
      current = AtlasRb::Resource.permissions(noid)
      return :already_private if current.nil?

      read = Array(current.read)
      return :already_private unless read.include?('public')

      AtlasRb::Work.metadata(noid, { 'permissions' => Permissions.envelope_with_read(current, read - ['public']) })
      :privatized
    end

    def report(actor:, set_noid:, title:, outcome:)
      CompletionNotice.deliver(
        kind:         'set_privatize',
        to_nuid:      actor,
        subject:      outcome.problems? ? 'Set privatize finished with problems' : 'Set privatize finished',
        body:         body_for(set_noid, title, outcome),
        subject_noid: set_noid,
        payload:      { title: title, privatized: outcome.counts[:privatized],
                        already_private: outcome.counts[:already_private],
                        truncated: outcome.truncated, failures: outcome.failures }
      )
    end

    def body_for(set_noid, title, outcome)
      count = outcome.counts[:privatized]
      lines = ["“#{title}”: #{count} work#{'s' unless count == 1} made private."]
      lines << "#{outcome.counts[:already_private]} were already private." if outcome.counts[:already_private].positive?
      (lines + sweep_report_tail(set_noid, outcome, 'These could not be changed and are still public:')).join("\n")
    end
end
