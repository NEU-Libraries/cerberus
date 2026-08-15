# frozen_string_literal: true

# The ACL write for a resource, and the policy that decides whether it may
# happen at all.
#
# This is the half of the permissions story that can fail. PermissionsForm
# decides what the submitted envelope *is*, reading params; this decides whether
# Atlas may be told about it, reading the resource's current audience and the
# actor's role. Keeping them apart means the controller holds neither: it hands
# over an envelope and reports whatever comes back.
#
# Three things can happen to a submitted ACL. It is written. It is deferred to
# VisibilityCascadeJob, because taking audience away from a Collection has to
# reach everything inside it and the container must be written last. Or it is
# refused, either by Atlas's own invariants or by the rule that only an
# administrator may restrict a Community.
class ResourcePermissions
  include AtlasWrite

  # Atlas's ACL invariants, phrased for the depositor and keyed on the envelope's
  # error code. An unrecognised code falls back to Atlas's own message, so a new
  # invariant still says something true rather than nothing.
  PERMISSIONS_REFUSED = {
    'visibility_exceeds_parent' => "Visibility wasn't changed — an item can't be more visible " \
                                   'than the collection or community it sits in. Make the ' \
                                   'container public first.'
  }.freeze

  # Communities have no cascade, so restricting one would leave every collection
  # inside it more visible than its container. The edit form routes this to an
  # administrator instead; this is the message when the form is bypassed.
  COMMUNITY_NARROWING_REFUSED = 'Restricting a community needs DRS administrators — it does not reach the ' \
                                'collections inside it. Nothing has been changed.'

  # What the caller should tell the user, if anything. A nil level means the
  # write went through and there is nothing to report — the ordinary case, and
  # the reason the controller side is two lines.
  Result = Struct.new(:level, :message, keyword_init: true) do
    def self.silent = new(level: nil, message: nil)

    def self.refused(message) = new(level: :alert, message: message)
  end

  # @param klass [String] 'Work', 'Collection' or 'Community'.
  # @param id [String] the resource's noid.
  # @param envelope [Hash] the submitted ACL, already parsed by PermissionsForm.
  # @param current_read [Array<String>] the resource's read ACL before this submit.
  # @param actor [User, nil] the acting user.
  def initialize(klass:, id:, envelope:, current_read: [], actor: nil)
    @klass        = klass
    @id           = id
    @envelope     = envelope
    @current_read = Array(current_read)
    @actor        = actor
  end

  # The edit path. A refusal is reported rather than raised: this runs BEFORE the
  # descriptive save in the same submit, so raising would discard title and
  # abstract edits that are independent of the ACL and perfectly valid.
  def apply!
    return Result.silent if @envelope.blank?

    deferral = narrowing_deferral
    return deferral if deferral

    write(@envelope)
  end

  # The create path, for an ACL written onto a resource that was just minted.
  #
  # Deliberately not #apply!. Two of that method's assumptions are false one line
  # after a create: there is no cascade to run, since nothing is inside a
  # resource this new, and current_read still describes the DESTINATION rather
  # than this resource — so the narrowing check would compare against the wrong
  # audience.
  #
  # The submitted grants are merged into the new resource's own envelope rather
  # than replacing it. Atlas assigns edit_groups, edit_users and embargo
  # unconditionally from the payload, so posting a form that names only read
  # groups would strip the grants Atlas gave the resource at create — including
  # the one the creator reaches it through.
  def apply_minted!
    submitted = @envelope[:permissions]
    return Result.silent if submitted.blank?

    write(permissions: minted_permissions.merge(submitted.symbolize_keys))
  end

  private

    def write(payload)
      with_stale_retry { AtlasRb.const_get(@klass).metadata(@id, payload) }
      Result.silent
    rescue AtlasRb::PermissionsError => e
      Result.refused(PERMISSIONS_REFUSED.fetch(e.code, e.message))
    end

    # Whether this change is handed off instead of written here, and what to say
    # about it. Returns nil when the ordinary write should go ahead.
    #
    # Works have nothing beneath them to strip, so they never defer. Communities
    # do, but they never cascade: narrowing one changes that object alone and
    # deliberately leaves its collections as visible as they were.
    def narrowing_deferral
      return nil if @klass == 'Work'
      return community_narrowing_refusal if @klass == 'Community'

      outcome = NarrowingRequest.call(noid: @id, current_read: @current_read,
                                      permissions: @envelope[:permissions] || {}, actor: @actor)
      return nil unless outcome.handled?

      Result.new(level: outcome.dispatched? ? :notice : :alert, message: outcome.message)
    end

    # A server-side backstop for the Community form, which offers Private to
    # administrators only. An admin's narrowing is written the ordinary way, with
    # no cascade. Anyone else reaching a narrowing here is JS-off or a hand-made
    # request, so it refuses rather than writing. Widening is unconstrained.
    def community_narrowing_refusal
      submitted = Array(@envelope.dig(:permissions, :read))
      return nil unless Permissions.narrowing?(current: @current_read, submitted: submitted)
      return nil if @actor&.admin?

      Result.refused(COMMUNITY_NARROWING_REFUSED)
    end

    # The ACL Atlas gave a resource at create, as the symbol-keyed hash the
    # metadata setter reads back. Only the grant lists are carried: `depositor`
    # and `proxy_uploader` are preserved by Atlas when omitted, and echoing them
    # would re-assert attribution this form has no business touching.
    def minted_permissions
      envelope = AtlasRb::Resource.permissions(@id)
      %i[read edit edit_users embargo].index_with { |key| envelope&.dig(key.to_s) }.compact
    end
end
