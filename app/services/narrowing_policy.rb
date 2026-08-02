# frozen_string_literal: true

# Who may narrow a container's visibility, given what the narrowing would touch.
#
# The rule is blast radius, and the two permitted cases are the tails of the
# curve. A depositor restricting a container holding only their own material
# risks nothing but their own work, and gating that would put friction on
# ordinary daily work for no safety gain. An admin is trusted with large
# consequences by definition. The middle is the dangerous part — enough rights
# to cascade over thousands of objects belonging to many depositors, without the
# authority to own the fallout — so it stops and asks instead of proceeding.
#
# Group-ACL editors and the devolved-admin tier fall in that middle and are
# refused. That is the intended outcome rather than an oversight in the
# phrasing: a staff curator with edit on an institutional container spanning
# many depositors cannot narrow it directly.
class NarrowingPolicy < ApplicationService
  # Why a narrowing was refused. Both route to the same "ask DRS staff"
  # affordance but say different things to the person who hit them.
  TOO_LARGE          = :too_large
  NOT_SOLE_DEPOSITOR = :not_sole_depositor

  # `affected` rather than `count` — a Struct member named count would shadow
  # Struct#count, and "how many resources this touches" is the clearer name for
  # what the confirmation copy is quoting anyway.
  Decision = Struct.new(:outcome, :reason, :affected, keyword_init: true) do
    def allowed? = outcome == :allowed
    def escalate? = outcome == :escalate
  end

  def initialize(impact:, actor:)
    @impact = impact
    @actor  = actor
  end

  def call
    # The size guard sits above the admin branch on purpose. It is not a
    # question of authority but of whether the cascade can finish: letting an
    # admin through would buy a half-narrowed subtree, which leaks exactly the
    # way an un-narrowed one does.
    return escalate(TOO_LARGE) if @impact.over_cap?
    return allowed if @actor&.admin?
    return allowed if @impact.wholly_owned_by?(@actor&.nuid)

    escalate(NOT_SOLE_DEPOSITOR)
  end

  private

    def allowed
      Decision.new(outcome: :allowed, affected: @impact.count)
    end

    def escalate(reason)
      Decision.new(outcome: :escalate, reason: reason, affected: @impact.count)
    end
end
