# frozen_string_literal: true

# Whether a Work's video may be played but not taken away.
#
# This is a licensing affordance, not a security boundary. A viewer who can play
# a file can always capture it, and nothing here pretends otherwise. What it owes
# the depositor is that the repository makes no offer it shouldn't: no download
# row, no "download it instead" line under the player, nothing in a bulk zip, and
# a refusal on the download route itself.
#
# It is expressed in vocabulary Atlas already has rather than a flag of its own.
# A video Blob is reachable by two routes that are gated differently —
# MediaController serves playback against the Work's own read ACL, while
# DownloadsController additionally consults the per-asset derivative gate. So
# "may I watch this" is a property of the Work and "may I keep a copy" is a
# property of the `video` tier, and restricting that tier is the whole feature.
#
# Atlas refuses a tier more visible than its Work, so the audience is computed
# against the Work's own read ACL rather than assumed — see .audience_for.
module StreamingOnly
  # The independent (non-cascading) tier covering video Blobs. An absent key
  # rides the Work's own visibility, which is what "not streaming only" means,
  # so turning the toggle off REMOVES the key rather than setting it public.
  TIER = 'video'

  # Full admins reach a restricted tier through Ability's `can :manage, :all`,
  # and a devolved admin is by definition a member of this group — so naming the
  # group alone covers both, and Ability never has to learn about
  # User#admin_delegate? (which it deliberately does not consult).
  ADMIN_AUDIENCE = [Permissions::ADMIN_GROUP].freeze

  # The tier audience to store for a Work whose read ACL is `read`.
  #
  # Atlas enforces tier ⊆ Work, so naming the admin group on a Work that does not
  # grant it would be refused outright (`tier_exceeds_resource`). Intersecting
  # instead always yields a legal policy and errs restrictive: on a public Work
  # the admin group survives, and on a group-restricted one the tier collapses to
  # `[]` — private, reachable only by a full admin's blanket ability. A
  # restricted Work's video is already limited to the people who can read it, so
  # that is a coherent floor rather than a degradation.
  def self.audience_for(read)
    return ADMIN_AUDIENCE if Array(read).include?('public')

    Array(read) & ADMIN_AUDIENCE
  end

  # True when `policy` carries a video tier this feature wrote.
  #
  # Deliberately an exact match. A `video` tier set by something else — a
  # Collection's Sentinel default, say — leaves the toggle reading "off", so
  # turning it off can never quietly widen a restriction this feature did not
  # impose. See .apply!, which only removes a tier it recognizes.
  def self.on?(policy, read: nil)
    Array(policy&.[](TIER)) == audience_for(read)
  end

  # Set or clear the video tier, preserving every other tier.
  #
  # The Atlas write is a whole-object REPLACE, so the stored policy is read back
  # and merged rather than posted bare — otherwise flipping this toggle would
  # silently drop the Work's image-ladder tiers. Returns without writing when
  # nothing would change, which keeps a no-op save out of the audit log.
  #
  # @param work_id [String] the Work's NOID.
  # @param enabled [Boolean] the requested state.
  # @param read [Array<String>] the Work's own read ACL, for .audience_for.
  # @param nuid [String, nil] the acting NUID.
  # @return [void]
  def self.apply!(work_id, enabled:, read:, nuid: nil)
    policy = stored_policy(work_id, nuid: nuid)
    return if enabled == on?(policy, read: read)

    if enabled
      policy[TIER] = audience_for(read)
    else
      # Only ever removes a tier matching what .on? recognizes; the guard above
      # has already established that, since enabled == false and on? == true.
      policy.delete(TIER)
    end

    AtlasRb::Work.set_derivative_permissions(work_id, policy: policy, nuid: nuid)
    nil
  end

  # The Work's stored tier map, as a plain mutable string-keyed Hash.
  #
  # There is no dedicated reader on the API; the map rides the Work payload.
  # (The write's own response carries it too, but nested under `work` rather
  # than at the top level the gem's docstring promises, so it is not used here.)
  def self.stored_policy(work_id, nuid: nil)
    work = AtlasRb::Work.find(work_id, nuid: nuid)
    (work&.dig('derivative_permissions') || {}).to_h.transform_values { |groups| Array(groups) }
  end

  # Whether this Work is one the toggle should be offered for at all: it has a
  # video Blob. Both the deposited master and any remuxed MP4 are video/*, so a
  # Work matches from the moment its content lands, not only once it is playable.
  # Delegates (image tiers) carry a `uri` and are not content.
  def self.applicable?(files)
    Array(files).any? { |file| file[:uri].blank? && file.mime_type.to_s.start_with?('video/') }
  end
end
