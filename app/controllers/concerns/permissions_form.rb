# frozen_string_literal: true

# Everything the permissions form needs before it renders, and the parse of the
# submitted form into an ACL envelope. This half decides nothing and writes
# nothing — ResourcePermissions owns the write and the policy that can refuse
# it. See docs/authorization.md and docs/permissions.md.
module PermissionsForm
  extend ActiveSupport::Concern

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

  # Reads `current_user`, NOT `effective_user`: Atlas resolves its actor from
  # the NUID signed off `Current.nuid`, so consulting the view-as target would
  # lock rows against a different principal than the write is evaluated as. A
  # nil user stays conservative. See docs/authorization.md.
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
    # Snapshot the read audience first: the next line REPLACES @permissions with
    # the form's rows, and pretty_resource_permissions mutates the envelope's
    # read list in place to strip the public sentinel, so there is no way back
    # to the audience as submitted afterwards.
    @read_groups = Array(raw_permissions&.read).dup
    @permissions = pretty_resource_permissions(raw_permissions)
    assign_visibility_ceiling(resource)
  end

  # Decides whether the Public option may be offered at all — Atlas refuses a
  # resource more visible than its container. See docs/authorization.md.
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

  # Order is load-bearing: the ceiling reads the destination's envelope, and
  # pretty_resource_permissions then MUTATES that same envelope (stripping the
  # public sentinel) before returning the form's rows, so the ceiling has to be
  # settled first. See docs/authorization.md.
  def new_form_permissions!(destination_id)
    inherited = @permissions
    assign_destination_ceiling(destination_id)
    @public = @public_allowed
    @groups = groups_for_permissions_picker
    @permissions = pretty_resource_permissions(inherited)
  end

  # A failed title lookup still withholds Public — the envelope has already said
  # the destination is private. See docs/authorization.md.
  def assign_destination_ceiling(destination_id)
    @public_allowed = Array(@permissions&.read).include?('public')
    return if @public_allowed

    node = AtlasRb::Resource.find(destination_id)
    @visibility_parent = { 'klass' => node&.dig('klass'),
                           'title' => node&.dig('resource', 'title').presence || DESTINATION_TITLE_UNKNOWN }
  rescue Faraday::Error, AtlasRb::Error, JSON::ParserError
    @visibility_parent = { 'title' => DESTINATION_TITLE_UNKNOWN }
  end

  # The "add a group" dropdown's candidate list. See docs/authorization.md.
  def groups_for_permissions_picker
    if current_user&.admin? || current_user&.admin_delegate?
      Group.for_select
    else
      pretty_user_permissions(current_user&.groups)
    end
  end

  # Permission / embargo fields, sent to Atlas's metadata PATCH. These are NOT
  # MODS and never touch the descriptive document; thumbnails ride the same edit
  # form but are persisted separately by apply_thumbnail.
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

  # `read` is always set definitively when `mass` is present, including to `[]`:
  # omitting the key leaves Atlas's stored read untouched, so a Private save
  # with no group grants would silently keep the item public. Public keeps the
  # group grants alongside the sentinel because a later flip to Private falls
  # back to them. See docs/authorization.md.
  def mass_permissions(permitted)
    return unless params[:mass]

    permitted[:permissions] ||= {}
    group_read = Array(permitted[:permissions][:read]) - ['public']
    permitted[:permissions][:read] = params[:mass] == 'public' ? (['public'] + group_read).uniq : group_read
  end
end
