# frozen_string_literal: true

# A per-tier derivative-permission policy bound (by noid) to a Collection or a
# Compilation (Set). `policy` maps each gated tier to the read groups that may
# fetch it; #apply_to pushes it to Atlas's per-tier gate. Two uses, both Cerberus
# orchestration: a Collection's Sentinel is the default applied to Works created
# under it, and a Set's Sentinel is bulk-applied across the Set's Works.
class Sentinel < ApplicationRecord
  # The image resolution ladder, in narrowing order: `small` (lowest res / widest
  # audience) → `master` (full-res source / narrowest). Monotonicity is checked
  # along this order only — a higher-res image can't be more open than a smaller
  # one below it, with `master` as the floor.
  IMAGE_LADDER = %w[small medium large service master].freeze

  # Non-image renditions gate independently — there is no meaningful resolution
  # ordering between an audio file and a PDF, so no monotonicity ties them.
  INDEPENDENT = %w[audio video pdf].freeze

  # Every gateable tier. `master` and the independent media reach non-image /
  # original binaries, which Atlas maps onto the matching assets; thumbnails are
  # never gateable (the open display pipe, public by construction).
  TIERS = (IMAGE_LADDER + INDEPENDENT).freeze

  validates :target_id, presence: true, uniqueness: true
  validate :policy_well_formed
  validate :policy_monotonic

  # The Collection default: apply that Collection's Sentinel to a Work just
  # created under it. No-op when the Collection has no Sentinel, so every create
  # path can call it unconditionally. Acts as the ambient Current principal (the
  # depositor / loader user), which holds edit rights on the fresh Work.
  def self.apply_default(collection_id, work_id)
    find_by(target_id: collection_id)&.apply_to(work_id)
  end

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

    # Visibility must narrow as image resolution grows: each rung's audience ⊆
    # the next-lower-res rung's (master ⊆ service ⊆ large ⊆ medium ⊆ small). A
    # permissive higher-res tier would void a stricter lower one — and the
    # enforcement side's coarse zoom cookie relies on this ordering. Only the
    # image ladder is ordered; the independent media (audio/video/pdf) are not
    # tied to it or to each other.
    def policy_monotonic
      return unless policy.is_a?(Hash)

      present = IMAGE_LADDER.select { |tier| policy[tier].is_a?(Array) }
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
