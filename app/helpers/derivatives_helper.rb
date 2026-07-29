# frozen_string_literal: true

# View + controller support for gated derivatives. Every downloadable asset —
# image-tier Delegates (S/M/L) and Blobs alike (master / PDF / audio / video) —
# carries a per-asset read gate (`gated`/`permission`) on the Work's assets
# payload. The downloads UI (which files to show), DerivativeDownloadsController
# (whether to authorize a delegate fetch), and DownloadsController (whether to
# authorize a blob stream) all decide access by projecting that gate onto a
# SolrDocument and asking the standard :read Ability — one source of truth.
# An active embargo on the containing Work is layered on top of that per-asset
# gate (see embargo_withholds?), not merged into it.
module DerivativesHelper
  # Public tier (gated: false) → readable by anyone; gated tier → only members
  # of its read groups (permission), which Atlas withholds from guests (nil →
  # empty → denied).
  def derivative_tier_document(delegate)
    read = delegate['gated'] ? Array(delegate['permission']) : ['public']
    SolrDocument.new('read_access_group_ssim' => read, 'internal_resource_tesim' => 'Work')
  end

  # Can the current viewer read this asset? Blobs (master / PDF / audio / video)
  # and delegate image tiers both carry `gated`/`permission`, so both project
  # onto the same :read Ability. An asset with no gate (`gated` falsy) resolves
  # to public — the safe default for anything Atlas hasn't stamped.
  # `embargo_date` is the containing Work's permissions.embargo — a blanket
  # hold checked ahead of (not instead of) the asset's own per-tier gate.
  def derivative_readable?(file, embargo_date: nil)
    !embargo_withholds?(embargo_date) && current_ability.can?(:read, derivative_tier_document(file))
  end

  # The downloadable assets the current viewer may actually fetch — used to keep
  # inaccessible tiers out of the downloads card, its modal, and its count.
  def downloadable_files(files, embargo_date: nil)
    files.select { |file| derivative_readable?(file, embargo_date: embargo_date) }
  end

  # A Work under an active embargo withholds every download — any tier, any
  # blob — from everyone except staff (grouper) or an Admin, regardless of the
  # asset's own gate. Distinct from :read: an embargoed Work's metadata/show
  # page still renders (see WorksController), only its downloads are held back.
  def embargo_withholds?(embargo_date)
    Embargo.active?(embargo_date) && !effective_user&.can_bypass_embargo?
  end

  # Controller-side raise for the two download-serving endpoints (Blob stream,
  # derivative-tier redirect): a second Atlas permissions read (the Work's own,
  # not the Blob's/tier's) is unavoidable here since neither's own gate carries
  # the containing Work's embargo.
  def deny_if_embargoed!(work_id)
    embargo_date = AtlasRb::Resource.permissions(work_id)&.embargo
    raise CanCan::AccessDenied if embargo_withholds?(embargo_date)
  end
end
