# frozen_string_literal: true

# Everything the permissions form needs before it renders, and everything the
# submitted form needs before it can be written: the pretty grant rows, the
# group picker, the visibility ceiling a resource inherits from its container,
# and the parse of the form's indexed permission rows into an ACL envelope.
#
# This half decides nothing and writes nothing. ResourcePermissions owns the
# write and the policy that can refuse it.
module PermissionsForm
  extend ActiveSupport::Concern

  # Stands in for a private destination's title when the lookup that would name
  # it fails. The sentence it lands in is already about a container the reader
  # just navigated through, so it reads as a reference rather than a gap.
  DESTINATION_TITLE_UNKNOWN = 'The destination container'

  def pretty_resource_permissions(perms)
    return [] if perms.blank?

    perms.read&.delete('public')
    perms.edit&.delete(Permissions::STAFF_EDIT_GROUP)
    perms.slice('read', 'edit').flat_map do |ability, values|
      Array(values).map do |group|
        Permissions::GrantRow.new(group_id: group, label: pretty_group(group),
                                  ability: ability, revocable: revocable_grant?(group))
      end
    end
  end

  # Whether the acting user may withdraw a grant naming `group` — the view-side
  # mirror of the Atlas rule that only a member of a group may remove its grant.
  # Reads `current_user`, NOT `effective_user`: the acting NUID Atlas resolves
  # its own actor from is signed from `Current.nuid`, which is the authenticated
  # user, so consulting the view-as target here would lock rows against a
  # different principal than the one the write is evaluated as. A nil user has no
  # membership to appeal to and stays conservative, matching how Atlas treats an
  # actor-less caller. The `public` token never reaches here — it is stripped
  # above and driven by the separate General Permissions control.
  def revocable_grant?(group)
    return true if current_user&.admin? || current_user&.admin_delegate?

    current_user&.member_of?(group) || false
  end

  def pretty_user_permissions(groups)
    return [] if groups.blank?

    groups.map { |value| [value, pretty_group(value)] }
  end

  def form_group_permissions(perms)
    perms.values.each_with_object({}) do |entry, acc|
      next unless entry['group_id'].present? && entry['ability'].present?

      ability = entry['ability']&.to_sym
      group_id = entry['group_id']
      acc[ability] ||= []
      acc[ability] << group_id
    end
  end

  def form_preparation(raw_permissions, resource: nil)
    @groups = groups_for_permissions_picker
    @public = raw_permissions&.read&.include?('public')
    @embargo = Embargo.release_date(raw_permissions&.embargo).to_s
    # Snapshot the read audience before anything else touches it. This line is
    # load-bearing twice over: the next one REPLACES @permissions (the Atlas
    # envelope the authorization gate loaded) with the form's row objects, and
    # pretty_resource_permissions mutates the envelope's read list in place to
    # strip the public sentinel — so a view wanting the audience as submitted
    # has no way back to it afterwards.
    @read_groups = Array(raw_permissions&.read).dup
    @permissions = pretty_resource_permissions(raw_permissions)
    assign_visibility_ceiling(resource)
  end

  # Decide whether the Public option may be offered. Atlas refuses a resource
  # more visible than its container (a 422 carrying `visibility_exceeds_parent`,
  # surfaced as AtlasRb::PermissionsError), so offering Public under a private
  # parent would only produce an error the depositor can't act on.
  # @visibility_parent names the blocking container so the form can say which
  # one is in the way. A root with no parent is unconstrained, as is a caller
  # that doesn't supply the resource.
  def assign_visibility_ceiling(resource)
    @public_allowed = true
    parent = Array(resource&.ancestors).last
    return if parent.blank?
    return if Array(AtlasRb::Resource.permissions(parent['noid'])&.read).include?('public')

    @public_allowed = false
    @visibility_parent = parent
  rescue Faraday::Error, JSON::ParserError
    # A parent lookup failure must not block the form — Atlas still enforces.
    @public_allowed = true
  end

  # Everything the permissions section of a *create* form needs.
  #
  # Atlas copies the destination's read ACL onto a new child wholesale — group
  # grants included — so the form opens holding exactly what the resource would
  # be born with, rather than a blank slate or a fixed default. That is what
  # lets it add a choice without moving the outcome: submit it untouched and the
  # ACL is the one inheritance would have produced anyway. A form that defaulted
  # to Private instead would quietly narrow every child of a public container,
  # and drop the inherited group grants with it.
  #
  # @narrowing_allowed stays unset, which is what puts _visibility_control on
  # its ordinary offered branch (see the `== false` test there) — there is
  # nothing inside a resource that does not exist to cascade to.
  #
  # Order is load-bearing twice. The ceiling reads the destination's envelope,
  # and pretty_resource_permissions then MUTATES that same envelope (stripping
  # the public sentinel) before returning the form's rows, so the ceiling has to
  # be settled first.
  #
  # @param destination_id [String] the container this resource will be made in.
  def new_form_permissions!(destination_id)
    inherited = @permissions
    assign_destination_ceiling(destination_id)
    @public = @public_allowed
    @groups = groups_for_permissions_picker
    @permissions = pretty_resource_permissions(inherited)
  end

  # The create-form counterpart to {#assign_visibility_ceiling}. That one walks
  # the resource's ancestors, which a resource that does not exist yet has
  # none of — but the create gate has already loaded the destination's envelope
  # into @permissions, and the destination IS the parent whose visibility bounds
  # the child. So the ceiling costs no extra call.
  #
  # Only the private branch needs the parent named, so the lookup for its title
  # is paid only there. A failed lookup still withholds Public: the envelope has
  # already said the destination is private, and Atlas would refuse the write
  # regardless, so generic copy beats a choice that cannot succeed.
  def assign_destination_ceiling(destination_id)
    @public_allowed = Array(@permissions&.read).include?('public')
    return if @public_allowed

    node = AtlasRb::Resource.find(destination_id)
    @visibility_parent = { 'klass' => node&.dig('klass'),
                           'title' => node&.dig('resource', 'title').presence || DESTINATION_TITLE_UNKNOWN }
  rescue Faraday::Error, AtlasRb::Error, JSON::ParserError
    @visibility_parent = { 'title' => DESTINATION_TITLE_UNKNOWN }
  end

  # The "add a group" dropdown's candidate list. An :admin or a devolved-admin
  # delegate (User#admin_delegate?) needs the full known-group registry to do
  # system-wide arbitrary permission adjustment — otherwise, scoped to the
  # acting user's own Grouper memberships (the everyday case: you can only
  # grant a group you're yourself in). Fixes a latent gap for full admins too:
  # an :admin with no personal Grouper groups (a legitimate shape — the role
  # itself is the grant) previously saw an empty picker.
  def groups_for_permissions_picker
    if current_user&.admin? || current_user&.admin_delegate?
      Group.for_select
    else
      pretty_user_permissions(current_user&.groups)
    end
  end

  # Permission / embargo fields, sent to Atlas's metadata PATCH. These are NOT
  # MODS and never touch the descriptive document. Thumbnails ride the same
  # edit form but are persisted separately by apply_thumbnail — they are
  # machine-set Delegate URIs with their own Atlas endpoint, not PATCH fields.
  def permission_params(resource_key)
    permitted = params.require(resource_key).permit(:embargo, permissions: [:group_id, :ability]).to_h
    transform_permissions(permitted, resource_key)
    mass_permissions(permitted)
    permitted
  end

  def transform_permissions(permitted, resource_key)
    return unless params[resource_key][:permissions]

    permitted[:permissions] = form_group_permissions(params[resource_key][:permissions])
    return if params[resource_key][:permissions][:embargo].nil?

    permitted[:permissions][:embargo] = params[resource_key][:permissions][:embargo]
  end

  # Apply the Public/Private visibility toggle to the read ACL. `read` is always
  # set definitively when `mass` is present, including to `[]` — omitting the key
  # leaves Atlas's stored read untouched, so a Private save with no group grants
  # would silently keep the item public.
  #
  # Public keeps the group grants alongside the sentinel rather than replacing
  # them. They grant nothing extra while the item is public, but they are what a
  # later flip to Private falls back to, so dropping them here would revoke a
  # grant the curator made in the very submit that added it. Sets compose their
  # read ACL the same way — see SetSharing#build_permissions.
  def mass_permissions(permitted)
    return unless params[:mass]

    permitted[:permissions] ||= {}
    group_read = Array(permitted[:permissions][:read]) - ['public']
    permitted[:permissions][:read] = params[:mass] == 'public' ? (['public'] + group_read).uniq : group_read
  end
end
