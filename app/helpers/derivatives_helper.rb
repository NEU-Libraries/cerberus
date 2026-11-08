# frozen_string_literal: true

# The per-asset download gate for views and controllers, layered under the
# Work's embargo. The rule lives in DerivativeGate. See docs/downloads.md.
module DerivativesHelper
  def derivative_tier_document(delegate, editors: {})
    DerivativeGate.document(delegate, editors: editors)
  end

  # `embargo_date` is the containing Work's permissions.embargo, checked ahead of
  # the asset's own gate. An edit grant does not lift it.
  def derivative_readable?(file, embargo_date: nil, editors: {})
    !embargo_withholds?(embargo_date) &&
      current_ability.can?(:read, derivative_tier_document(file, editors: editors))
  end

  def downloadable_files(files, embargo_date: nil, editors: {})
    files.select { |file| derivative_readable?(file, embargo_date: embargo_date, editors: editors) }
  end

  # @param permissions the Work's AtlasRb::Resource.permissions, as
  #   authorize_show! leaves it in @permissions.
  def work_editors(permissions)
    DerivativeGate.editors_from_permissions(permissions)
  end

  # Staff and admins only. An embargoed Work's show page still renders; only its
  # downloads are held back.
  def embargo_withholds?(embargo_date)
    Embargo.active?(embargo_date) && !effective_user&.can_bypass_embargo?
  end

  # From the row's own Solr doc only: no Atlas read. See docs/downloads.md.
  def offer_downloads?(document)
    return false unless document.klass == Work
    return false if embargo_withholds?(document.try(:embargo_release_date))

    has_downloads = document['has_downloads_bsi']
    return true if has_downloads.nil? # indexed before Atlas rolled the fields up
    return false unless has_downloads

    gate = DerivativeGate.editors_from_doc(document)
                         .merge('read_access_group_ssim'  => Array(document['download_read_groups_ssim']),
                                'internal_resource_tesim' => 'Work')
    current_ability.can?(:read, SolrDocument.new(gate))
  end

  # Neither a Blob's nor a tier's own gate carries the containing Work's
  # embargo, so the download endpoints read the Work's permissions as well.
  # Returns them, so the tier gate's edit grant needs no second read.
  def deny_if_embargoed!(work_id)
    permissions = AtlasRb::Resource.permissions(work_id)
    raise CanCan::AccessDenied if embargo_withholds?(permissions&.embargo)

    permissions
  end
end
