# frozen_string_literal: true

# The per-asset download gate, in a form that does not need a view context.
#
# Atlas stamps every downloadable asset with `gated` / `permission` and leaves
# enforcement to the display layer, so Cerberus decides access by projecting that
# stamp onto a SolrDocument and asking the standard :read Ability — one rule,
# whether the caller is a view filtering rows, a controller authorizing a stream,
# or a zip packer deciding what goes in the archive.
#
# DerivativesHelper is the view/controller face of this and delegates here; the
# bulk-download packers call it directly, since they run outside a request and
# have no current_ability to reach for.
module DerivativeGate
  # An asset Atlas has not stamped resolves to public — the safe default for
  # anything predating the gate. A gated asset whose `permission` is nil (what
  # Atlas returns to guests) resolves to an empty audience, and so is denied.
  def self.document(asset)
    read = asset['gated'] ? Array(asset['permission']) : ['public']
    SolrDocument.new('read_access_group_ssim' => read, 'internal_resource_tesim' => 'Work')
  end

  # @param asset [Hash] one entry from AtlasRb::Work.assets.
  # @param ability [Ability] the caller's ability.
  def self.readable?(asset, ability)
    ability.can?(:read, document(asset))
  end
end
