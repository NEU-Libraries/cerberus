# frozen_string_literal: true

# The shared #update entry point for the Work, Collection and Community
# Metadata and Permissions tabs — separate forms that all PATCH the same action
# with disjoint fields — and the ACL write it guards.
#
# The pieces it composes each own one half of that job: PermissionsForm parses
# and presents, DescriptiveMetadata and AdvancedMetadata merge MODS, AtlasWrite
# makes a write survive the wire. What is left here is the routing between them
# and the policy that can refuse an ACL change outright.
module Transformable
  extend ActiveSupport::Concern

  include AtlasWrite
  include PermissionsForm
  include DescriptiveMetadata
  include AdvancedMetadata

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

  # Shared #update handler for the Work/Collection/Community Metadata + Permissions
  # tabs (separate forms, both PATCH #update with disjoint fields). Permissions go
  # to Atlas's metadata endpoint; descriptive fields are validated then merged
  # into the existing MODS and written via the structure-safe raw `update` path.
  def handle_metadata_update(klass:, resource_key:, keywords:)
    id = params[:id]
    show_path = public_send("#{klass.downcase}_path", id)

    if advanced_submitted?(resource_key)
      save_advanced!(klass, id, **advanced_params(resource_key))
      return redirect_to(show_path)
    end

    apply_permissions(klass, id, resource_key)
    apply_thumbnail(klass, id)
    return redirect_to(show_path) unless descriptive_submitted?(resource_key)

    apply_descriptive(klass, id, resource_key, keywords, show_path)
  end

  # A refused ACL write is a 422, not a 403 — the caller may hold full edit
  # rights and still trip an invariant. Report it and carry on rather than
  # bouncing the whole submit: this runs BEFORE the descriptive save, so raising
  # would discard title/abstract edits that are independent and perfectly valid.
  # The form suppresses the offending choice up front (shared/_visibility_control),
  # so reaching here means JS-off, tampering, or the container narrowing between
  # page load and submit.
  def apply_permissions(klass, id, resource_key)
    perms = permission_params(resource_key)
    return if perms.blank?
    return if narrowing_handed_off?(klass, perms)

    with_stale_retry { AtlasRb.const_get(klass).metadata(id, perms) }
  rescue AtlasRb::PermissionsError => e
    flash[:alert] = PERMISSIONS_REFUSED.fetch(e.code, e.message)
  end

  # Write a create form's permissions onto a resource that was just minted.
  #
  # Deliberately not #apply_permissions. That one is the edit path, and two of
  # its assumptions are false one line after a create: there is no cascade to
  # run (nothing is inside a resource this new), and @permissions still holds
  # the DESTINATION's envelope from the create gate rather than this resource's
  # — so NarrowingRequest would compare against the wrong audience and address
  # a nil noid.
  #
  # The submitted grants are merged into the new resource's own envelope rather
  # than replacing it. Atlas assigns edit_groups, edit_users and embargo
  # unconditionally from the payload, so posting a form that names only read
  # groups would strip the grants Atlas gave the resource at create — including
  # the one the creator reaches it through.
  def apply_new_permissions(klass, id, resource_key)
    submitted = permission_params(resource_key)[:permissions]
    return if submitted.blank?

    payload = { permissions: minted_permissions(id).merge(submitted.symbolize_keys) }
    with_stale_retry { AtlasRb.const_get(klass).metadata(id, payload) }
  rescue AtlasRb::PermissionsError => e
    flash[:alert] = PERMISSIONS_REFUSED.fetch(e.code, e.message)
  end

  # The ACL Atlas gave a resource at create, as the symbol-keyed hash the
  # metadata setter reads back. Only the grant lists are carried: `depositor`
  # and `proxy_uploader` are preserved by Atlas when omitted, and echoing them
  # would re-assert attribution this form has no business touching.
  def minted_permissions(id)
    envelope = AtlasRb::Resource.permissions(id)
    %i[read edit edit_users embargo].index_with { |key| envelope&.dig(key.to_s) }.compact
  end

  # Taking audience away from a Collection has to reach everything inside it,
  # and the container is written LAST, so this save is skipped entirely and the
  # whole change is handed to the cascade. Returns true when that happened —
  # including when it was refused, since a refusal must not fall through to the
  # ordinary write.
  #
  # Works have nothing beneath them to strip, so they never take this branch.
  # Communities do, but they never cascade: narrowing one changes that object
  # alone and deliberately leaves its collections as visible as they were.
  def narrowing_handed_off?(klass, perms)
    return false if klass == 'Work'
    return community_narrowing_refused?(perms) if klass == 'Community'

    outcome = NarrowingRequest.call(noid: params[:id], current_read: Array(@permissions&.read),
                                    permissions: perms[:permissions] || {}, actor: current_user)
    return false unless outcome.handled?

    flash[outcome.dispatched? ? :notice : :alert] = outcome.message
    true
  end

  # A server-side backstop for the Community form, which offers Private to
  # administrators only. An admin's narrowing is written the ordinary way, with
  # no cascade — the community's own object changes and nothing below it does.
  # Anyone else reaching a narrowing here is JS-off or a hand-made request, so
  # it refuses rather than writing. Widening is unconstrained for everyone.
  def community_narrowing_refused?(perms)
    submitted = Array(perms.dig(:permissions, :read))
    return false unless Permissions.narrowing?(current: Array(@permissions&.read), submitted: submitted)
    return false if current_user&.admin?

    flash[:alert] = COMMUNITY_NARROWING_REFUSED
    true
  end
end
