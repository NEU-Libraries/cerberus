# frozen_string_literal: true

# Whether a Work's video may be played but not taken away -- a licensing
# affordance, NOT a security boundary. Two Atlas facts shape this: a tier may
# not be more visible than its Work (intersect, never assume), and
# set_derivative_permissions is a whole-object REPLACE (read back and merge, or
# the Work's image tiers are silently dropped). See docs/derivatives.md.
module StreamingOnly
  # An ABSENT key means "off", so turning the toggle off REMOVES the key.
  TIER = 'video'

  # Naming the group covers full admins, so Ability never learns admin_delegate?.
  ADMIN_AUDIENCE = [Permissions::ADMIN_GROUP].freeze

  def self.audience_for(read)
    return ADMIN_AUDIENCE if Array(read).include?('public')

    Array(read) & ADMIN_AUDIENCE
  end

  # Exact match, so turning off can never widen a restriction this feature did
  # not impose. The key? test is NOT redundant: audience_for is [] on a Work that
  # does not grant the admin group, which an ABSENT tier compares equal to.
  def self.on?(policy, read: nil)
    return false unless policy.respond_to?(:key?) && policy.key?(TIER)

    Array(policy[TIER]) == audience_for(read)
  end

  # Set or clear the video tier, preserving every other tier. The Atlas write is
  # a whole-object REPLACE, so the stored policy is read back and merged.
  def self.apply!(work_id, enabled:, read:, nuid: nil)
    policy = stored_policy(work_id, nuid: nuid)
    return if enabled == on?(policy, read: read)

    if enabled
      policy[TIER] = audience_for(read)
    else
      policy.delete(TIER)
    end

    AtlasRb::Work.set_derivative_permissions(work_id, policy: policy, nuid: nuid)
    nil
  end

  # No dedicated reader; the map rides the Work payload. The write's own response
  # nests it under `work`, not where the gem's docstring promises.
  def self.stored_policy(work_id, nuid: nil)
    work = AtlasRb::Work.find(work_id, nuid: nuid)
    (work&.dig('derivative_permissions') || {}).to_h.transform_values { |groups| Array(groups) }
  end

  # Delegates (image tiers) carry a `uri` and are not content; both the deposited
  # master and any remuxed MP4 are video/*.
  def self.applicable?(files)
    Array(files).any? { |file| file[:uri].blank? && file.mime_type.to_s.start_with?('video/') }
  end
end
