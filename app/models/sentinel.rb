# frozen_string_literal: true

# A per-tier derivative-permission policy bound (by noid) to a Collection or a
# Compilation (Set). `policy` maps each gated tier to the read groups that may
# fetch it; #apply_to pushes it to Atlas's per-tier gate. Two uses, both Cerberus
# orchestration: a Collection's Sentinel is the default applied to Works created
# under it, and a Set's Sentinel is bulk-applied across the Set's Works.
class Sentinel < ApplicationRecord
  # Tiers in narrowing-resolution order: `small` (lowest res / widest audience) →
  # `service` (full-res zoom / narrowest). Monotonicity is checked along this order.
  TIERS = %w[small medium large service].freeze

  validates :target_id, presence: true, uniqueness: true
  validate :policy_well_formed
  validate :policy_monotonic

  # Apply this policy to a Work's derivatives via Atlas's per-tier gate.
  def apply_to(work_id, nuid: nil)
    AtlasRb::Work.set_derivative_permissions(work_id, policy: tier_policy, nuid: nuid)
  end

  # The policy narrowed to known tiers (stray keys dropped before the API call).
  def tier_policy
    policy.slice(*TIERS)
  end

  private

    # Each present tier maps to an array of read-group strings.
    def policy_well_formed
      return errors.add(:policy, 'must be a hash') unless policy.is_a?(Hash)

      policy.each do |tier, groups|
        errors.add(:policy, "unknown tier '#{tier}'") unless TIERS.include?(tier.to_s)
        errors.add(:policy, "'#{tier}' must be a list of read groups") unless groups.is_a?(Array)
      end
    end

    # Visibility must narrow as resolution grows: each tier's audience ⊆ the
    # next-lower-res tier's (service ⊆ large ⊆ medium ⊆ small). A permissive
    # higher-res tier would void a stricter lower one — and the enforcement
    # side's coarse zoom cookie relies on this ordering.
    def policy_monotonic
      return unless policy.is_a?(Hash)

      present = TIERS.select { |tier| policy[tier].is_a?(Array) }
      present.each_cons(2) do |wider, narrower|
        next if audience_subset?(policy[narrower], policy[wider])

        errors.add(:policy, "'#{narrower}' must be at least as restrictive as '#{wider}'")
      end
    end

    # Is `inner`'s audience a subset of `outer`'s? 'public' is the universal audience.
    def audience_subset?(inner, outer)
      return true  if Array(outer).include?('public')  # outer = everyone → any inner ⊆
      return false if Array(inner).include?('public')  # inner public, outer not → wider
      Array(inner).to_set.subset?(Array(outer).to_set)
    end
end
