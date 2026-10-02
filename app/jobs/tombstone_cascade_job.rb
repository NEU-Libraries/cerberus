# frozen_string_literal: true

# Withdraws a container and everything live beneath it, deepest first, with one
# removal reason, then records every NOID it withdrew in one ledger entry. See
# docs/admin.md ("Deleting a container that is not empty").
#
# There is no cascading restore. The ledger entry is the list a developer
# restores from, parents first, so it must name every item this run withdrew
# and nothing withdrawn before it.
class TombstoneCascadeJob < ApplicationJob
  queue_as :default

  # Atlas answers a lock conflict with a 409 on the raw response. Retried in
  # place rather than through retry_on: a re-run rebuilds the walk without the
  # items already withdrawn, and its ledger entry would leave them out.
  LOCK_ATTEMPTS = 3

  def perform(noid:, uuid:, klass:, title:, reason:)
    withdrawn = []
    failures = []

    TombstoneTargets.new(noid: noid, uuid: uuid).each do |target|
      response = tombstone(target.noid, reason)
      if response.success?
        withdrawn << { 'noid' => target.noid, 'type' => target.klass }
      else
        failures << "#{target.klass} #{target.noid}: #{failure_text(response)}"
      end
    end

    report(container: { noid: noid, klass: klass, title: title }, reason: reason,
           withdrawn: withdrawn, failures: failures)
  end

  private

    def tombstone(noid, reason)
      LOCK_ATTEMPTS.times do
        response = AtlasRb::Resource.tombstone(noid, reason: reason)
        return response unless response.status == 409
      end
      AtlasRb::Resource.tombstone(noid, reason: reason)
    end

    # A container refuses while a member it holds failed above, so the root of
    # a failure reads plainly and its parents read as consequences.
    def failure_text(response)
      code = JSON.parse(response.body.to_s)['code']
      code == 'has_live_children' ? 'still holds a live member' : "Atlas answered #{response.status}"
    rescue JSON::ParserError
      "Atlas answered #{response.status}"
    end

    def report(container:, reason:, withdrawn:, failures:)
      CompletionNotice.deliver(
        kind:         'tombstone_cascade',
        to_nuid:      Current.nuid,
        subject:      subject_for(container, failures),
        body:         body_for(container, withdrawn, failures),
        subject_noid: container[:noid],
        payload:      { subject_type: container[:klass], subject_title: container[:title], reason: reason,
                        withdrawn: withdrawn, failures: failures }
      )
    end

    def subject_for(container, failures)
      verb = failures.any? ? 'was not fully deleted' : 'deleted'
      %(#{container[:klass]} “#{container[:title]}” #{verb})
    end

    def body_for(container, withdrawn, failures)
      lines = ["#{withdrawn.size} item#{'s' unless withdrawn.size == 1} withdrawn, " \
               "#{container[:klass].downcase} included."]
      lines += ['', 'These could not be withdrawn and are still live:', *failures] if failures.any?
      lines += ['', 'There is no one-step restore. To bring these back, ask the development team: ' \
                    'this entry lists every item withdrawn.']
      lines.join("\n")
    end
end
