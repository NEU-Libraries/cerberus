# frozen_string_literal: true

# Metadata-form handling shared by the Work/Collection/Community controllers:
# permission transforms (pretty_*/form_*/mass_permissions) plus the structure-safe
# descriptive save path (parse MODS -> fields, merge edits back, write raw XML).
module Transformable # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  def pretty_resource_permissions(perms)
    return [] if perms.blank?

    perms.read&.delete('public')
    perms.edit&.delete(Permissions::STAFF_EDIT_GROUP)
    perms.slice('read', 'edit').flat_map do |key, values|
      permission = key == 'read' ? 'View' : 'Manage'
      Array(values).map { |value| [value, pretty_group(value), permission] }
    end
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

  def form_preparation(raw_permissions)
    @groups = pretty_user_permissions(current_user&.groups)
    @public = raw_permissions&.read&.include?('public')
    @embargo = begin
      Date.parse(raw_permissions&.embargo.to_s).to_s
    rescue Date::Error, TypeError
      ''
    end
    @permissions = pretty_resource_permissions(raw_permissions)
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

  # Permission / embargo / thumbnail fields, sent to Atlas's metadata PATCH.
  # These are NOT MODS and never touch the descriptive document.
  def permission_params(resource_key)
    permitted = params.require(resource_key).permit(:embargo, permissions: [:group_id, :ability]).to_h
    transform_permissions(permitted, resource_key)
    mass_permissions(permitted)
    add_thumbnail(permitted)
    permitted
  end

  # Merge the descriptive fields into the existing MODS and write via the raw,
  # structure-safe update path — preserving every curated node the form does not
  # own, and skipping the write (and a needless OCFL MODS version) on a no-op.
  def save_descriptive!(klass, id, title:, description:, keywords: nil)
    xml = AtlasRb.const_get(klass).mods(id, 'xml')
    merged = Metadata::MODSMerge.call(xml: xml, title: title, abstract: description, keywords: keywords)
    return if Metadata::MODSMerge.unchanged?(xml, merged)

    AtlasRb.const_get(klass).update(id, write_tmp_xml(merged))
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
    return redirect_to(show_path) unless descriptive_submitted?(resource_key)

    apply_descriptive(klass, id, resource_key, keywords, show_path)
  end

  def apply_permissions(klass, id, resource_key)
    perms = permission_params(resource_key)
    AtlasRb.const_get(klass).metadata(id, perms) if perms.present?
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
    xml = AtlasRb.const_get(klass).mods(id, 'xml')
    merged = Metadata::MODSMerge.call(xml: xml, **fields)
    return if Metadata::MODSMerge.unchanged?(xml, merged)

    AtlasRb.const_get(klass).update(id, write_tmp_xml(merged))
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
