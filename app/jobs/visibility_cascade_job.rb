# frozen_string_literal: true

# Applies a container's narrowed read audience down its subtree, deepest first.
#
# The caller does NOT write the container before enqueuing — this job narrows it
# last, after everything beneath it (see NarrowingTargets for why the order is
# load-bearing). Every write is clamped and skipped when it changes nothing. See
# docs/authorization.md.
#
# The ledger entry lists each item it narrowed with the read audience it had,
# because widening the collection again never widens what is inside it. That is
# the list a developer undoes a narrowing from (docs/narrowing.md).
class VisibilityCascadeJob < ApplicationJob
  queue_as :default

  # A lock conflict is retried on the one item, not through retry_on: a re-run
  # skips what is already narrowed, and its ledger entry would leave it out.
  LOCK_ATTEMPTS = 3

  def perform(noid:, uuid:, permissions:)
    actor = Current.nuid
    @tally = { narrowed: 0, unchanged: 0, container: 0 }
    @changed = []
    failures = []
    read_groups = Array(permissions['read'])

    NarrowingTargets.new(noid: noid, uuid: uuid).each do |target|
      with_lock_retry { target.noid == noid ? write_container(target, permissions) : apply(target, read_groups) }
    rescue AtlasRb::Error => e
      failures << "#{target.klass} #{target.noid}: #{e.message}"
    end

    report(actor: actor, noid: noid, failures: failures)
  end

  private

    def with_lock_retry
      attempts = 0
      begin
        yield
      rescue AtlasRb::StaleResourceError
        attempts += 1
        retry if attempts < LOCK_ATTEMPTS
        raise
      end
    end

    # The container is written last, verbatim from what was submitted, and is
    # deliberately NOT clamped: round-tripping the stored envelope instead would
    # silently drop edit-group or embargo edits made in the same submit.
    def write_container(target, permissions)
      before = Array(AtlasRb::Resource.permissions(target.noid)&.read)
      AtlasRb::Resource.set_permissions(target.noid, permissions)
      clamp_sentinel(target.noid, Array(permissions['read']))
      record(target, before)
      @tally[:container] += 1
    end

    def apply(target, container_read)
      current = AtlasRb::Resource.permissions(target.noid)
      return @tally[:unchanged] += 1 if current.nil?

      clamped = Permissions.audience_intersect(Array(current.read), container_read)
      return @tally[:unchanged] += 1 if clamped.sort == Array(current.read).sort

      AtlasRb::Resource.set_permissions(target.noid, { 'read' => clamped })
      clamp_sentinel(target.noid, clamped)
      record(target, Array(current.read))
      @tally[:narrowed] += 1
    end

    def record(target, read_before)
      @changed << { 'noid' => target.noid, 'type' => target.klass, 'read_before' => read_before }
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
    def report(actor:, noid:, failures:)
      CompletionNotice.deliver(
        kind:         'visibility_cascade',
        to_nuid:      actor,
        subject:      failures.any? ? 'Visibility change finished with problems' : 'Visibility change finished',
        body:         body_for(noid, @tally, failures),
        subject_noid: noid,
        payload:      { narrowed: @tally[:narrowed], unchanged: @tally[:unchanged], failures: failures,
                        changed: @changed }
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
