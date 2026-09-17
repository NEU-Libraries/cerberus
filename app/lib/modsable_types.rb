# frozen_string_literal: true

# The Atlas types that carry an editable MODS document. Atlas names the same set
# with its own `Modsable` concern, and atlas_rb's `mods_versions` doc names the
# same three. See docs/people-and-routing.md.
module ModsableTypes
  TYPES = [AtlasRb::Work, AtlasRb::Collection, AtlasRb::Community].freeze

  # Stated, never inferred from the gem's surface: `Resource.mods` is defined on
  # the base class, so EVERY subclass answers it and a FileSet's read succeeds
  # while returning nothing a curator can edit. Only these three take a MODS
  # write — theirs is the `update` that accepts `origin:` — and only these three
  # have a show route to send the curator back to.
  #
  # Takes a type name rather than a class, so a caller hands over whatever Atlas
  # or Solr gave it. A type atlas_rb does not map is not Modsable either, so
  # class_for's raise becomes a plain false rather than an error a gate cannot
  # act on.
  def self.include?(type_name)
    TYPES.include?(AtlasRb::Resource.class_for(type_name))
  rescue ArgumentError
    false
  end
end
