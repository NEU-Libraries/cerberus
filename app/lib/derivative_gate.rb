# frozen_string_literal: true

# The per-asset download gate, without a view context, so the zip packers apply
# the same rule as the views and controllers. See docs/downloads.md.
module DerivativeGate
  # What Ability#edit_equivalent? reads. A packer that reads these off a Solr doc
  # must declare them, or Solr omits them and every editor is refused.
  EDITOR_FIELDS = %w[edit_access_group_ssim edit_access_person_ssim depositor_ssi].freeze

  # An unstamped asset is public. A gated one whose `permission` is nil (what
  # Atlas sends a guest) has an empty audience, so only `editors` can admit.
  def self.document(asset, editors: {})
    read = asset['gated'] ? Array(asset['permission']) : ['public']
    SolrDocument.new(editors.merge('read_access_group_ssim' => read, 'internal_resource_tesim' => 'Work'))
  end

  # @param editors [Hash] the containing Work's EDITOR_FIELDS.
  def self.readable?(asset, ability, editors: {})
    ability.can?(:read, document(asset, editors: editors))
  end

  # @param permissions the Work's AtlasRb::Resource.permissions, or nil.
  def self.editors_from_permissions(permissions)
    return {} if permissions.nil?

    { 'edit_access_group_ssim'  => Array(permissions.edit),
      'edit_access_person_ssim' => Array(permissions.try(:edit_users)),
      'depositor_ssi'           => permissions.try(:depositor) }
  end

  # @param doc [SolrDocument, Hash] the Work's own Solr doc.
  def self.editors_from_doc(doc)
    EDITOR_FIELDS.index_with { |field| doc[field] }
  end
end
