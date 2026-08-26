# frozen_string_literal: true

# The Advanced tab (Works only): structured title parts and the editable
# personal/corporate creators, driven off the shared NEU::MODS gem. Same
# merge-not-replace contract as the descriptive fields, over a wider set of
# nodes.
module AdvancedMetadata
  extend ActiveSupport::Concern
  include AtlasWrite

  # Advanced-tab (Works only) load: structured title parts + the editable
  # personal/corporate creators (plain, Creator-role) for pre-fill, plus the
  # preserved (authority-bearing / non-Creator) names shown read-only. Driven off
  # the shared NEU::MODS gem — exactly what save_advanced! merges back.
  def load_advanced!(klass)
    doc = NEU::MODS::Document.parse(resource_mods(klass))
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
end
