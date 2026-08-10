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

  # Communities have no cascade, so restricting one would leave every collection
  # inside it more visible than its container. The edit form routes this to an
  # administrator instead; this is the message when the form is bypassed.
  COMMUNITY_NARROWING_REFUSED = 'Restricting a community needs DRS administrators — it does not reach the ' \
                                'collections inside it. Nothing has been changed.'

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
    parent = Array(resource&.ancestor_chain).last
    return if parent.blank?
    return if Array(AtlasRb::Resource.permissions(parent['noid'])&.read).include?('public')

    @public_allowed = false
    @visibility_parent = parent
  rescue Faraday::Error, JSON::ParserError
    # A parent lookup failure must not block the form — Atlas still enforces.
    @public_allowed = true
  end

  # Everything the permissions section of a *create* form needs. The resource
  # does not exist yet, so it has no grants to show and nothing beneath it to
  # cascade to: the rows start empty and @narrowing_allowed stays unset, which
  # is what puts shared/_visibility_control on its ordinary offered branch (see
  # the `== false` test there).
  #
  # Order is load-bearing. The ceiling is read off the destination container's
  # envelope, which @permissions holds from the create gate until the last line
  # replaces it with the form's (empty) row list.
  #
  # @param destination_id [String] the container this resource will be made in.
  def new_form_permissions!(destination_id)
    assign_destination_ceiling(destination_id)
    # Private, matching the ACL Atlas mints a container with (read: []). The
    # control adds a choice here; it must not also move the outcome for someone
    # who leaves it alone, and of the two directions to be wrong in silently,
    # publishing is the one that cannot be taken back.
    @public = false
    @groups = groups_for_permissions_picker
    @permissions = []
  end

  # The create-form counterpart to {#assign_visibility_ceiling}. That one walks
  # the resource's ancestor_chain, which a resource that does not exist yet has
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

  # `keywords: true` means "this resource must carry at least one subject", and the
  # Keywords box is how a depositor supplies one. A record whose subjects are all
  # authority-controlled already satisfies that, and those subjects are curated:
  # MODSFields keeps them out of the box on purpose and MODSMerge never writes over
  # them. So the form posts `curated_subjects` and it counts here — otherwise a
  # curator fixing a title on such a record must invent a redundant keyword to save.
  def descriptive_valid?(descriptive, keywords: false, curated_subjects: false)
    return false if descriptive[:title].blank?
    return false if keywords && Array(descriptive[:keywords]).empty? && !curated_subjects

    true
  end

  # Cast the flag the descriptive form posts alongside the MODS fields. Kept out of
  # descriptive_params because that hash is splatted straight into save_descriptive!
  # as the MODS payload, and this is not a MODS field.
  #
  # Trusting a form value is fine here: the guard is a curation prompt, not a
  # security boundary — Atlas is that — so the worst a tampered value buys is a Work
  # saved with no subjects, which the API permits anyway.
  def curated_subjects_posted?(resource_key)
    ActiveModel::Type::Boolean.new.cast(params.dig(resource_key, :curated_subjects)).present?
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

  def apply_descriptive(klass, id, resource_key, keywords, show_path)
    descriptive = descriptive_params(resource_key, keywords: keywords)
    unless descriptive_valid?(descriptive, keywords:         keywords,
                                           curated_subjects: curated_subjects_posted?(resource_key))
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
