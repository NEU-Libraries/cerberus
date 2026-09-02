# frozen_string_literal: true

# A per-tier derivative-permission policy bound (by noid) to a Collection or a
# Compilation (Set). `policy` maps each gated tier to the read groups that may
# fetch it; #apply_to pushes it to Atlas's per-tier gate. See docs/narrowing.md.
class Sentinel < ApplicationRecord
  # The image resolution ladder, in narrowing order: `small` (widest audience)
  # to `master` (narrowest). Monotonicity is checked along this order, so
  # reordering this array changes what the validation below means.
  IMAGE_LADDER = %w[small medium large service master].freeze

  INDEPENDENT = %w[audio video pdf].freeze

  # Every gateable tier. Thumbnails are deliberately absent — they are the open
  # display pipe, public by construction.
  TIERS = (IMAGE_LADDER + INDEPENDENT).freeze

  # The read groups of the Collection/Set this Sentinel defaults for, set by the
  # authoring controller. nil means the container-relative check below is
  # skipped, so leaving it unset silently drops that ceiling.
  attr_accessor :resource_read_groups

  validates :target_id, presence: true, uniqueness: true
  validate :policy_well_formed
  validate :policy_monotonic
  validate :policy_within_resource

  def self.apply_default(collection_id, work_id)
    find_by(target_id: collection_id)&.apply_to(work_id)
  end

  def apply_to(work_id, nuid: nil)
    AtlasRb::Work.set_derivative_permissions(work_id, policy: tier_policy, nuid: nuid)
  end

  # The policy narrowed to known tiers (stray keys dropped before the API call).
  def tier_policy
    policy.slice(*TIERS)
  end

  private

    def policy_well_formed
      return errors.add(:policy, 'must be a hash') unless policy.is_a?(Hash)

      policy.each do |tier, groups|
        errors.add(:policy, "unknown tier '#{tier}'") unless TIERS.include?(tier.to_s)
        errors.add(:policy, "'#{tier}' must be a list of read groups") unless groups.is_a?(Array)
      end
    end

    # Visibility must narrow as image resolution grows: each rung's audience ⊆
    # the next-lower-res rung's (master ⊆ service ⊆ large ⊆ medium ⊆ small). A
    # permissive higher-res tier voids a stricter lower one, and the enforcement
    # side's coarse zoom cookie relies on this ordering.
    def policy_monotonic
      return unless policy.is_a?(Hash)

      present = IMAGE_LADDER.select { |tier| policy[tier].is_a?(Array) }
      present.each_cons(2) do |wider, narrower|
        next if audience_subset?(policy[narrower], policy[wider])

        errors.add(:policy, "'#{narrower}' must be at least as restrictive as '#{wider}'")
      end
    end

    # A tier can't be more visible than the container it defaults for. Skipped
    # when the container's groups weren't supplied.
    def policy_within_resource
      return if resource_read_groups.nil?
      return unless policy.is_a?(Hash)

      tier_policy.each do |tier, groups|
        next if audience_subset?(groups, resource_read_groups)

        errors.add(:policy, "'#{tier}' can't be more visible than the collection")
      end
    end

    # Is `inner`'s audience a subset of `outer`'s? 'public' is the universal audience.
    def audience_subset?(inner, outer)
      return true  if Array(outer).include?('public')  # outer = everyone → any inner ⊆
      return false if Array(inner).include?('public')  # inner public, outer not → wider

      Array(inner).to_set.subset?(Array(outer).to_set)
    end
end
