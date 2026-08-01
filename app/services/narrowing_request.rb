# frozen_string_literal: true

# A submitted permissions change that would take audience away from a
# Collection, and what should happen to it.
#
# Widening needs none of this — descendants keep their own narrower ACLs and
# the containment invariant still holds — so an ordinary save falls straight
# through and this reports :not_narrowing.
#
# When it IS a narrowing, the synchronous write is skipped entirely rather than
# being followed by a cascade. The container has to be written last (see
# VisibilityCascadeJob), so writing it here would open exactly the window the
# bottom-up order exists to avoid, and doing it in two passes would cost a
# second OCFL version on every visibility change.
class NarrowingRequest < ApplicationService
  Outcome = Struct.new(:status, :message, keyword_init: true) do
    # Whether the caller should skip its own write.
    def handled? = status != :not_narrowing
    def dispatched? = status == :dispatched
  end

  # Phrased for the depositor rather than the rule. "Ask DRS staff" is the whole
  # affordance for now; the request form lands in a later slice.
  UNCHANGED = 'Nothing has been changed.'

  REFUSALS = {
    NarrowingPolicy::NOT_SOLE_DEPOSITOR => 'This collection holds material deposited by other people, ' \
                                           "so restricting it needs DRS staff. #{UNCHANGED}",
    NarrowingPolicy::TOO_LARGE          => 'This collection is too large to restrict in one go — ' \
                                           "DRS staff will need to run it. #{UNCHANGED}"
  }.freeze

  # @param noid [String] the Collection being edited.
  # @param current_read [Array<String>] its read audience before this submit.
  # @param permissions [Hash] the submitted ACL envelope.
  # @param actor [User, nil] the acting user.
  def initialize(noid:, current_read:, permissions:, actor:)
    @noid         = noid
    @current_read = Array(current_read)
    @permissions  = permissions
    @actor        = actor
  end

  def call
    return Outcome.new(status: :not_narrowing) unless narrowing?

    decision = NarrowingPolicy.call(impact: impact, actor: @actor)
    return Outcome.new(status: :refused, message: REFUSALS[decision.reason]) if decision.escalate?

    dispatch(decision)
  end

  private

    def narrowing?
      Permissions.narrowing?(current: @current_read, submitted: submitted_read)
    end

    def submitted_read
      Array(@permissions[:read] || @permissions['read'])
    end

    def impact
      NarrowingImpact.new(noid: container.id, uuid: container.valkyrie_id)
    end

    # Costs one lookup, but only on the narrowing branch: the update path
    # doesn't otherwise load the resource, and the subtree query needs the
    # Solr uuid, which only the resource carries.
    def container
      @container ||= AtlasRb::Collection.find(@noid)
    end

    def dispatch(decision)
      VisibilityCascadeJob.perform_later(noid: container.id, uuid: container.valkyrie_id,
                                         permissions: wire_permissions)
      Outcome.new(status: :dispatched, message: dispatched_message(decision.affected))
    end

    # String keys before the job goes on the queue. The form path builds this
    # hash with symbol keys, and it has to survive serialization and arrive
    # shaped the way Atlas reads it.
    def wire_permissions
      @permissions.to_h.transform_keys(&:to_s)
    end

    def dispatched_message(affected)
      return 'Restricting this collection. Nothing was inside it to change.' if affected.zero?

      "Restricting this collection and the #{affected} item#{'s' unless affected == 1} inside it. " \
        "You'll get an inbox message when it's done."
    end
end
