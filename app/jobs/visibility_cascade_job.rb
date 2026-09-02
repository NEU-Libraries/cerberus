# frozen_string_literal: true

# Applies a container's narrowed read audience down its subtree, deepest first.
#
# The caller does NOT write the container before enqueuing — this job narrows it
# last, after everything beneath it (see NarrowingTargets for why the order is
# load-bearing). Re-running is safe: every write is clamped and skipped when it
# changes nothing. See docs/authorization.md.
class VisibilityCascadeJob < ApplicationJob
  queue_as :default

  # Safe to back off and re-run only because the cascade is idempotent.
  retry_on AtlasRb::StaleResourceError, wait: :polynomially_longer, attempts: 5

  def perform(noid:, uuid:, permissions:)
    actor = Current.nuid
    tally = { narrowed: 0, unchanged: 0, container: 0 }
    failures = []
    read_groups = Array(permissions['read'])

    NarrowingTargets.new(noid: noid, uuid: uuid).each do |target|
      tally[target.noid == noid ? write_container(target, permissions) : apply(target, read_groups)] += 1
    # Let a lock conflict escape to retry_on rather than recording it as a
    # failure — it is transient, and the job is idempotent.
    rescue AtlasRb::StaleResourceError
      raise
    rescue AtlasRb::Error => e
      failures << "#{target.klass} #{target.noid}: #{e.message}"
    end

    report(actor: actor, noid: noid, tally: tally, failures: failures)
  end

  private

    # The container is written last, verbatim from what was submitted, and is
    # deliberately NOT clamped: round-tripping the stored envelope instead would
    # silently drop edit-group or embargo edits made in the same submit.
    #
    # @return [Symbol]
    def write_container(target, permissions)
      target.atlas_class.metadata(target.noid, { 'permissions' => permissions })
      clamp_sentinel(target.noid, Array(permissions['read']))
      :container
    end

    # @return [Symbol] :narrowed or :unchanged
    def apply(target, container_read)
      current = AtlasRb::Resource.permissions(target.noid)
      return :unchanged if current.nil?

      clamped = Permissions.audience_intersect(Array(current.read), container_read)
      return :unchanged if clamped.sort == Array(current.read).sort

      target.atlas_class.metadata(target.noid, { 'permissions' => Permissions.envelope_with_read(current, clamped) })
      clamp_sentinel(target.noid, clamped)
      :narrowed
    end

    # The derivative-access default lives in Cerberus, not in the ACL Atlas
    # holds, so it must be clamped here too: Atlas refuses a tier more visible
    # than its Work, and a stale default makes the next deposit into that
    # collection fail outright. See docs/authorization.md.
    def clamp_sentinel(noid, read_groups)
      sentinel = Sentinel.find_by(target_id: noid)
      return if sentinel.nil?

      clamped = sentinel.policy.transform_values do |groups|
        Permissions.audience_intersect(Array(groups), read_groups)
      end
      return if clamped == sentinel.policy

      sentinel.update(policy: clamped)
    end

    # Anything that failed to narrow is still exposed, so failures are named
    # rather than counted. See docs/authorization.md.
    def report(actor:, noid:, tally:, failures:)
      CompletionNotice.deliver(
        kind:         'visibility_cascade',
        to_nuid:      actor,
        subject:      failures.any? ? 'Visibility change finished with problems' : 'Visibility change finished',
        body:         body_for(noid, tally, failures),
        subject_noid: noid,
        payload:      { narrowed: tally[:narrowed], unchanged: tally[:unchanged], failures: failures }
      )
    end

    def body_for(noid, tally, failures)
      lines = ["#{tally[:narrowed]} item#{'s' unless tally[:narrowed] == 1} narrowed to match the collection."]
      lines << "#{tally[:unchanged]} were already at least that restricted." if tally[:unchanged].positive?
      lines += ['', 'These could not be changed and may still be visible:', *failures] if failures.any?
      # A path, not a _url: a job has no request to take a host from, and the
      # inbox renders these in-app anyway (same choice LoadReport makes).
      lines += ['', Rails.application.routes.url_helpers.collection_path(noid)]
      lines.join("\n")
    end
end
