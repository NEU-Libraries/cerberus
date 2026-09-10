# frozen_string_literal: true

# Who may narrow a container's visibility, given what the narrowing would touch.
# See docs/narrowing.md.
class NarrowingPolicy < ApplicationService
  TOO_LARGE          = :too_large
  NOT_SOLE_DEPOSITOR = :not_sole_depositor

  # `affected` rather than `count`: a Struct member named count would shadow
  # Struct#count.
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
    # question of authority but of whether the cascade can finish: an admin let
    # through buys a half-narrowed subtree, which leaks like an un-narrowed one.
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
