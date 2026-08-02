# frozen_string_literal: true

# Applies a container's narrowed read audience down its subtree, deepest first.
#
# The caller does NOT write the container before enqueuing — this job narrows
# the container last, after everything beneath it (see NarrowingTargets for why
# the order is load-bearing). It is handed the intended audience, not a fait
# accompli.
#
# Re-running is safe: each resource is clamped against the container's audience
# and skipped when that changes nothing, so a retry after a partial run only
# finishes the remainder.
class VisibilityCascadeJob < ApplicationJob
  queue_as :default

  # Atlas retries its own optimistic-lock conflicts and only surfaces this once
  # its budget is exhausted — which during a deposit means finalize jobs are
  # still touching the same resources. Backing off and re-running is safe here
  # precisely because the cascade is idempotent.
  retry_on AtlasRb::StaleResourceError, wait: :polynomially_longer, attempts: 5

  # @param noid [String] the container being narrowed.
  # @param uuid [String] its Solr id, for the subtree lookup.
  # @param permissions [Hash] the container's whole submitted ACL envelope. The
  #   container is written from this verbatim, so an edit-group or embargo
  #   change made in the same submit rides along; descendants are clamped
  #   against its `read` rather than taking a copy of it.
  def perform(noid:, uuid:, permissions:)
    actor = Current.nuid
    tally = { narrowed: 0, unchanged: 0, container: 0 }
    failures = []
    read_groups = Array(permissions['read'])

    NarrowingTargets.new(noid: noid, uuid: uuid).each do |target|
      tally[target.noid == noid ? write_container(target, permissions) : apply(target, read_groups)] += 1
    # Let a lock conflict escape to retry_on rather than recording it as a
    # failure — it is transient, and the job is idempotent, so re-running the
    # whole cascade costs only the writes it already made being skipped.
    rescue AtlasRb::StaleResourceError
      raise
    rescue AtlasRb::Error => e
      failures << "#{target.klass} #{target.noid}: #{e.message}"
    end

    report(actor: actor, noid: noid, tally: tally, failures: failures)
  end

  private

    # The container itself, written last and taken verbatim from what was
    # submitted — the person editing it said exactly what they wanted, and by
    # this point every descendant is already within it. Deliberately not
    # clamped: clamping against its own new audience would be a no-op, and
    # round-tripping the stored envelope would silently drop the edit-group or
    # embargo edits made in the same submit.
    #
    # Tallied separately from the descendants: the report speaks to what else
    # changed ("the items inside it"), and the person already knows they
    # restricted the container — they just asked for it.
    #
    # @return [Symbol]
    def write_container(target, permissions)
      target.atlas_class.metadata(target.noid, { 'permissions' => permissions })
      :container
    end

    # @return [Symbol] :narrowed or :unchanged
    def apply(target, container_read)
      current = AtlasRb::Resource.permissions(target.noid)
      return :unchanged if current.nil?

      clamped = Permissions.audience_intersect(Array(current.read), container_read)
      return :unchanged if clamped.sort == Array(current.read).sort

      target.atlas_class.metadata(target.noid, { 'permissions' => envelope(current, clamped) })
      :narrowed
    end

    # The resource's whole ACL envelope with only `read` replaced.
    #
    # Atlas's permissions setter assigns edit_groups, edit_users and the embargo
    # unconditionally from the incoming hash, so a payload carrying `read` alone
    # would collapse edit_groups to the staff auto-prepend and blank the embargo
    # release date. depositor and proxy_uploader are the exception and are
    # deliberately omitted: those are write-once, and the setter only touches
    # them when the key is present.
    def envelope(current, read)
      { 'embargo'    => current.embargo,
        'read'       => read,
        'edit'       => Array(current.edit),
        'edit_users' => Array(current.edit_users) }
    end

    # A cascade is slow enough that whoever triggered it has moved on, and a
    # partial result is the one outcome they must not have to discover for
    # themselves — anything that failed to narrow is still exposed, so failures
    # are named rather than counted.
    def report(actor:, noid:, tally:, failures:)
      return if actor.blank?

      SystemMessage.deliver(
        to_nuid: actor,
        subject: failures.any? ? 'Visibility change finished with problems' : 'Visibility change finished',
        body:    body_for(noid, tally, failures)
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
