# frozen_string_literal: true

# View + controller support for the gated image-derivative tiers (S/M/L).
# Each downloadable asset carries an advisory per-tier read gate
# (`gated`/`permission`); both the downloads UI (which tiers to show) and
# DerivativeDownloadsController (whether to authorize a fetch) decide access by
# projecting that gate onto a SolrDocument and asking the standard :read
# Ability — one source of truth for the mapping.
module DerivativesHelper
  # Public tier (gated: false) → readable by anyone; gated tier → only members
  # of its read groups (permission), which Atlas withholds from guests (nil →
  # empty → denied).
  def derivative_tier_document(delegate)
    read = delegate['gated'] ? Array(delegate['permission']) : ['public']
    SolrDocument.new('read_access_group_ssim' => read, 'internal_resource_tesim' => 'Work')
  end

  # Blobs carry no per-tier gate (the work's own read gate, already passed to
  # reach the page, governs them); delegate tiers are checked against theirs.
  def derivative_readable?(file)
    return true if file['uri'].blank?

    current_ability.can?(:read, derivative_tier_document(file))
  end

  # The downloadable assets the current viewer may actually fetch — used to keep
  # inaccessible tiers out of the downloads card, its modal, and its count.
  def downloadable_files(files)
    files.select { |file| derivative_readable?(file) }
  end
end
