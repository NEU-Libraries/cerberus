# frozen_string_literal: true

# A permission policy bound (by noid) to a Collection or a Compilation (Set).
# `policy` maps each gated derivative tier to the read groups that may fetch it;
# `work_access` optionally changes the Work's own ACL. #apply_to writes both to
# one Work. See docs/narrowing.md.
class Sentinel < ApplicationRecord
  include SentinelWorkAccess

  # The image resolution ladder, in narrowing order: `small` (widest audience)
  # to `original` (narrowest). Monotonicity is checked along this order, so
  # reordering this array changes what the validation below means.
  IMAGE_LADDER = %w[small medium large service original].freeze

  INDEPENDENT = %w[audio video pdf].freeze

  # Every gateable tier. Thumbnails are deliberately absent — they are the open
  # display pipe, public by construction.
  TIERS = (IMAGE_LADDER + INDEPENDENT).freeze

  # What #apply_to did to one Work's ACL, so a sweep can ledger the audience it
  # replaced. The tiers are not recorded: they are rewritten on every apply.
  Application = Struct.new(:acl_changed, :read_before, :edit_before, keyword_init: true)

  # The read groups of the Collection/Set this Sentinel defaults for, set by the
  # authoring controller. nil means the container-relative check below is
  # skipped, so leaving it unset silently drops that ceiling.
  attr_accessor :resource_read_groups

  validates :target_id, presence: true, uniqueness: true
  validate :policy_well_formed
  validate :policy_monotonic
  validate :policy_within_resource

  # `work_access: false` is for the interactive deposit, where the depositor has
  # just chosen the Work's ACL themselves. See docs/narrowing.md.
  def self.apply_default(collection_id, work_id, work_access: true)
    find_by(target_id: collection_id)&.apply_to(work_id, work_access: work_access)
  end

  # The ACL is written first because Atlas refuses a tier naming a group its
  # Work does not grant, so the tiers are clamped against the audience the Work
  # has after the write. Returns nil when the Work cannot be read.
  def apply_to(work_id, nuid: nil, work_access: true)
    current = AtlasRb::Resource.permissions(work_id)
    return if current.nil?

    envelope = work_envelope(current) if work_access
    changed = envelope.present? && acl_change?(envelope, current)
    AtlasRb::Resource.set_permissions(work_id, envelope, nuid: nuid) if changed

    read = changed ? envelope['read'] : Array(current.read)
    AtlasRb::Work.set_derivative_permissions(work_id, policy: clamped_tiers(read), nuid: nuid) if derivatives_enabled
    Application.new(acl_changed: changed, read_before: Array(current.read), edit_before: editable_groups(current))
  end

  # Keeps the Sentinel coherent after its container narrows underneath it:
  # Atlas refuses a tier or a Work more visible than the container, so a stale
  # default would fail the next ingest outright. See docs/authorization.md.
  def clamp_to!(read_groups)
    clamped_policy = policy.transform_values { |groups| Permissions.audience_intersect(Array(groups), read_groups) }
    clamped_access = clamped_work_access(read_groups)
    return if clamped_policy == policy && clamped_access == work_access

    update(policy: clamped_policy, work_access: clamped_access)
  end

  # The policy narrowed to known tiers (stray keys dropped before the API call).
  def tier_policy
    policy.slice(*TIERS)
  end

  private

    def clamped_tiers(read)
      tier_policy.transform_values { |groups| Permissions.audience_intersect(Array(groups), read) }
    end

    def policy_well_formed
      return errors.add(:policy, 'must be a hash') unless policy.is_a?(Hash)

      policy.each do |tier, groups|
        errors.add(:policy, "unknown tier '#{tier}'") unless TIERS.include?(tier.to_s)
        errors.add(:policy, "'#{tier}' must be a list of read groups") unless groups.is_a?(Array)
      end
    end

    # Visibility must narrow as image resolution grows: each rung's audience ⊆
    # the next-lower-res rung's (original ⊆ service ⊆ large ⊆ medium ⊆ small). A
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
