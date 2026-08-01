# frozen_string_literal: true

# Metadata-form handling shared by the Work/Collection/Community controllers:
# permission transforms (pretty_*/form_*/mass_permissions) plus the structure-safe
# descriptive save path (parse MODS -> fields, merge edits back, write raw XML).
module Transformable # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  # Atlas's ACL invariants, phrased for the depositor and keyed on the envelope's
  # error code. An unrecognised code falls back to Atlas's own message, so a new
  # invariant still says something true rather than nothing.
  PERMISSIONS_REFUSED = {
    'visibility_exceeds_parent' => "Visibility wasn't changed — an item can't be more visible " \
                                   'than the collection or community it sits in. Make the ' \
                                   'container public first.'
  }.freeze

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
    parent = Array(resource&.ancestor_chain).last
    return if parent.blank?
    return if Array(AtlasRb::Resource.permissions(parent['noid'])&.read).include?('public')

    @public_allowed = false
    @visibility_parent = parent
  rescue Faraday::Error, JSON::ParserError
    # A parent lookup failure must not block the form — Atlas still enforces.
    @public_allowed = true
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

  # Descriptive (MODS) fields the simple Metadata form owns; symbol-keyed for
  # MODSMerge. `keywords: false` (containers) leaves keyword subjects untouched.
  def descriptive_params(resource_key, keywords: false)
    raw = params.require(resource_key).permit(:title, :description, keywords: [])
    {
      title:       raw[:title],
      description: raw[:description],
      keywords:    keywords ? clean_keywords(raw[:keywords]) : nil
    }
  end

  # True when the request carried the descriptive (Metadata-tab) form rather than
  # the permissions form — both POST to #update with disjoint fields.
  def descriptive_submitted?(resource_key)
    params[resource_key].respond_to?(:key?) && params[resource_key].key?(:title)
  end

  def descriptive_valid?(descriptive, keywords: false)
    return false if descriptive[:title].blank?
    return false if keywords && Array(descriptive[:keywords]).empty?

    true
  end

  # Create-path title guard (containers): flashes and returns true when the
  # permitted params carry no title, so the controller can redirect back before
  # minting an Atlas resource — a blank title otherwise yields a silently
  # untitled object (MODSMerge leaves a blank title untouched).
  def title_missing?(permitted)
    return false if permitted['title'].present?

    flash[:alert] = 'Please provide a title.'
    true
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

  # Merge the descriptive fields into the existing MODS and write via the raw,
  # structure-safe update path — preserving every curated node the form does not
  # own, and skipping the write (and a needless OCFL MODS version) on a no-op.
  # Wrapped in with_stale_retry: right after a deposit the async ingest/derivative
  # jobs are still finalizing the same Work, so this read→merge→write can lose an
  # optimistic-lock race; re-reading picks up the current MODS + token.
  def save_descriptive!(klass, id, title:, description:, keywords: nil)
    with_stale_retry do
      xml = AtlasRb.const_get(klass).mods(id, 'xml')
      merged = Metadata::MODSMerge.call(xml: xml, title: title, abstract: description, keywords: keywords)
      break if Metadata::MODSMerge.unchanged?(xml, merged)

      AtlasRb.const_get(klass).update(id, write_tmp_xml(merged))
    end
  end

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

  # Taking audience away from a Collection has to reach everything inside it,
  # and the container is written LAST, so this save is skipped entirely and the
  # whole change is handed to the cascade. Returns true when that happened —
  # including when it was refused, since a refusal must not fall through to the
  # ordinary write.
  #
  # Collections only. Works have nothing beneath them to strip, and Communities
  # are deliberately out of scope for the cascade.
  def narrowing_handed_off?(klass, perms)
    return false unless klass == 'Collection'

    outcome = NarrowingRequest.call(noid: params[:id], current_read: Array(@permissions&.read),
                                    permissions: perms[:permissions] || {}, actor: current_user)
    return false unless outcome.handled?

    flash[outcome.dispatched? ? :notice : :alert] = outcome.message
    true
  end

  def apply_descriptive(klass, id, resource_key, keywords, show_path)
    descriptive = descriptive_params(resource_key, keywords: keywords)
    unless descriptive_valid?(descriptive, keywords: keywords)
      flash[:alert] = keywords ? 'Please provide a title and at least one keyword.' : 'Please provide a title.'
      return redirect_back_or_to(public_send("edit_#{klass.downcase}_path", id))
    end

    save_descriptive!(klass, id, **descriptive)
    redirect_to show_path
  end

  # Parse the simple-form descriptive fields out of the resource's raw MODS so
  # the edit form pre-fills with the BARE title (+ read-only structured parts),
  # the abstract, and the free-text keywords — exactly what #update merges back.
  def load_descriptive!(klass)
    @descriptive = Metadata::MODSFields.call(xml: AtlasRb.const_get(klass).mods(params[:id], 'xml'))
  end

  # Advanced-tab (Works only) load: structured title parts + the editable
  # personal/corporate creators (plain, Creator-role) for pre-fill, plus the
  # preserved (authority-bearing / non-Creator) names shown read-only. Driven off
  # the shared NEU::MODS gem — exactly what save_advanced! merges back.
  def load_advanced!(klass)
    doc = NEU::MODS::Document.parse(AtlasRb.const_get(klass).mods(params[:id], 'xml'))
    parts = doc.title_parts
    @advanced = {
      subtitle: parts[:subtitle], part_name: parts[:part_name],
      part_number: parts[:part_number], non_sort: parts[:non_sort],
      personal_creators: doc.editable_personal_creators,
      corporate_creators: doc.editable_corporate_creators,
      preserved_names: doc.preserved_names
    }
  end

  # True when the Advanced-tab form (not Metadata/Permissions) was submitted —
  # routed on its hidden form marker, since all three PATCH #update.
  def advanced_submitted?(resource_key)
    params.dig(resource_key, :form) == 'advanced'
  end

  # Advanced-tab fields, mapped to MODSMerge's vocabulary (form first/last ->
  # given/family). Blank title parts ("") clear the part; blank creator rows are
  # dropped by MODSMerge.
  def advanced_params(resource_key)
    raw = params.require(resource_key).permit(
      :subtitle, :part_name, :part_number, :non_sort,
      personal_creators: %i[first last], corporate_creators: []
    )
    {
      subtitle: raw[:subtitle], part_name: raw[:part_name],
      part_number: raw[:part_number], non_sort: raw[:non_sort],
      personal_creators: Array(raw[:personal_creators]).map { |c| { given: c[:first], family: c[:last] } },
      corporate_creators: Array(raw[:corporate_creators])
    }
  end

  # Merge the Advanced-tab fields into the existing MODS via the structure-safe
  # raw update path, skipping the write on a no-op (same spine as save_descriptive!).
  def save_advanced!(klass, id, **fields)
    with_stale_retry do
      xml = AtlasRb.const_get(klass).mods(id, 'xml')
      merged = Metadata::MODSMerge.call(xml: xml, **fields)
      break if Metadata::MODSMerge.unchanged?(xml, merged)

      AtlasRb.const_get(klass).update(id, write_tmp_xml(merged))
    end
  end

  # Atlas enforces optimistic locking server-side and raises
  # AtlasRb::StaleResourceError (HTTP 409) only once its own retry budget is
  # exhausted. During a deposit the async ingest/derivative jobs are still
  # finalizing the Work (Work.complete, Delegate PATCHes), so an interactive
  # metadata/permissions save can lose the race. Re-run the block so each attempt
  # re-reads the current state and token, backing off briefly between tries.
  # atlas_rb blesses this pattern via retry_on for jobs; the interactive path
  # needs its own bounded loop.
  def with_stale_retry(attempts: 5)
    tries = 0
    begin
      yield
    rescue AtlasRb::StaleResourceError
      tries += 1
      raise if tries >= attempts

      sleep(0.2 * tries)
      retry
    end
  end

  def clean_keywords(raw)
    Array(raw).map { |k| k.to_s.strip }.reject(&:empty?).uniq
  end

  def write_tmp_xml(xml)
    path = Rails.root.join('tmp', "#{SecureRandom.uuid}.xml").to_s
    File.write(path, xml)
    path
  end

  def transform_permissions(permitted, resource_key)
    return unless params[resource_key][:permissions]

    permitted[:permissions] = form_group_permissions(params[resource_key][:permissions])
    return if params[resource_key][:permissions][:embargo].nil?

    permitted[:permissions][:embargo] = params[resource_key][:permissions][:embargo]
  end

  # Apply the Public/Private visibility toggle to the read ACL. Always sets
  # `read` definitively when `mass` is present: 'public' becomes `['public']`;
  # private becomes the explicit group-read list minus the public sentinel —
  # which is `[]` when there are no group grants. The earlier version only
  # *deleted* 'public' from an existing read array, so a Private save with no
  # group grants produced no `read` key at all, Atlas left read unchanged, and
  # the item silently stayed public (a disclosure bug).
  def mass_permissions(permitted)
    return unless params[:mass]

    permitted[:permissions] ||= {}
    group_read = Array(permitted[:permissions][:read]) - ['public']
    permitted[:permissions][:read] = params[:mass] == 'public' ? ['public'] : group_read
  end
end
