# frozen_string_literal: true

# Whether a Work's audio or video may be played but not taken away -- a licensing
# affordance, NOT a security boundary. Two Atlas facts shape this: a tier may
# not be more visible than its Work (intersect, never assume), and
# set_derivative_permissions is a whole-object REPLACE (read back and merge, or
# the Work's image tiers are silently dropped). See docs/derivatives.md.
module StreamingOnly
  # Atlas's tier key for a Blob is its media type. An ABSENT key means "off", so
  # turning the toggle off REMOVES the key. Only the Work's own media type is
  # written: a Sentinel policy writes these keys too, and the Permissions tab
  # lists every key present, so an audio tier on a video Work would read as a
  # real limit.
  MEDIA_TIERS = %w[video audio].freeze

  # Naming the group covers full admins, so Ability never learns admin_delegate?.
  ADMIN_AUDIENCE = [Permissions::ADMIN_GROUP].freeze

  def self.audience_for(read)
    return ADMIN_AUDIENCE if Array(read).include?('public')

    Array(read) & ADMIN_AUDIENCE
  end

  # Exact match, so turning off can never widen a restriction this feature did
  # not impose. The key? test is NOT redundant: audience_for is [] on a Work that
  # does not grant the admin group, which an ABSENT tier compares equal to.
  def self.on?(policy, tiers:, read: nil)
    return false if tiers.empty? || !policy.respond_to?(:key?)

    tiers.all? { |tier| policy.key?(tier) && Array(policy[tier]) == audience_for(read) }
  end

  # Set or clear the Work's media tiers, preserving every other tier. The Atlas
  # write is a whole-object REPLACE, so the stored policy is read back and merged.
  def self.apply!(work_id, enabled:, read:, tiers:, nuid: nil)
    return if tiers.empty?

    policy = stored_policy(work_id, nuid: nuid)
    return if enabled == on?(policy, tiers: tiers, read: read)

    tiers.each do |tier|
      if enabled
        policy[tier] = audience_for(read)
      elsif Array(policy[tier]) == audience_for(read)
        policy.delete(tier)
      end
    end

    AtlasRb::Work.set_derivative_permissions(work_id, policy: policy, nuid: nuid)
    nil
  end

  # No dedicated reader; the map rides the Work payload. The write's own response
  # nests it under `work`, not where the gem's docstring promises.
  def self.stored_policy(work_id, nuid: nil)
    policy_from(AtlasRb::Work.find(work_id, nuid: nuid))
  end

  # The same map off a Work payload already in hand, so a show page can ask
  # without a second read.
  def self.policy_from(work)
    (work&.dig('derivative_permissions') || {}).to_h.transform_values { |groups| Array(groups) }
  end

  # The media tiers a Work's content Blobs fall under. Delegates (image tiers)
  # carry a `uri` and are not content; a remuxed MP4 shares its master's type.
  def self.tiers_for(files)
    tiers_for_mime_types(Array(files).select { |file| file[:uri].blank? }.map(&:mime_type))
  end

  def self.tiers_for_mime_types(mime_types)
    Array(mime_types).map { |mime| mime.to_s.split('/').first }.uniq & MEDIA_TIERS
  end

  def self.applicable?(files)
    tiers_for(files).any?
  end
end
