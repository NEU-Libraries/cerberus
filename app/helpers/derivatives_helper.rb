# frozen_string_literal: true

# View + controller support for gated derivatives. Every downloadable asset —
# image-tier Delegates (S/M/L) and Blobs alike (master / PDF / audio / video) —
# carries a per-asset read gate (`gated`/`permission`) on the Work's assets
# payload. The downloads UI (which files to show), DerivativeDownloadsController
# (whether to authorize a delegate fetch), and DownloadsController (whether to
# authorize a blob stream) all decide access by projecting that gate onto a
# SolrDocument and asking the standard :read Ability — one source of truth.
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
  def derivative_readable?(file)
    current_ability.can?(:read, derivative_tier_document(file))
  end

  # The downloadable assets the current viewer may actually fetch — used to keep
  # inaccessible tiers out of the downloads card, its modal, and its count.
  def downloadable_files(files)
    files.select { |file| derivative_readable?(file) }
  end
end
