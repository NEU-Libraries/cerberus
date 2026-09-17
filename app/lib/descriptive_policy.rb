# frozen_string_literal: true

# DRS editorial rules about the descriptive metadata a form must carry. These
# are Cerberus-side policy: Atlas accepts a MODS document either way. See
# docs/edit-surfaces.md.
module DescriptivePolicy
  # Works must carry at least one keyword; containers need not. The container
  # forms have no Keywords box at all, so requiring one there would make a
  # title-only edit unsaveable.
  KEYWORDS_REQUIRED = [AtlasRb::Work].freeze

  def self.keywords_required?(atlas_class) = KEYWORDS_REQUIRED.include?(atlas_class)
end
