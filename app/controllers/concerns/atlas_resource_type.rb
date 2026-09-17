# frozen_string_literal: true

# Which Atlas type a controller edits, declared once and read by the shared edit
# concerns. See docs/edit-surfaces.md.
module AtlasResourceType
  extend ActiveSupport::Concern

  class_methods do
    # All three are stated, never derived from one another. The UI and Atlas
    # vocabularies diverge deliberately — Atlas's Compilation is the UI's Set —
    # so a params key or a route guessed from the class name is right for
    # Work/Collection/Community and wrong for the next type added.
    #
    # @param klass [Class] the AtlasRb resource class.
    # @param key [Symbol] the strong-params / form key.
    # @param route [Symbol] the resourceful route name, giving both
    #   <route>_path and edit_<route>_path.
    def atlas_resource(klass, key:, route:)
      define_method(:atlas_class)  { klass }
      define_method(:resource_key) { key }
      define_method(:show_path) { |id| public_send(:"#{route}_path", id) }
      define_method(:edit_path) { |id| public_send(:"edit_#{route}_path", id) }
    end
  end

  # The type name Atlas reports in internal_resource, which is what the Solr
  # documents CanCan gates on carry. Derived from atlas_class rather than from
  # the controller name: a mismatch here evaluates the wrong ability rule
  # instead of raising, so it must follow Atlas's vocabulary, not the UI's.
  def solr_type = atlas_class.name.demodulize

  # Declared by each includer via .atlas_resource. Raising rather than returning
  # nil: without it a controller joining the shared edit concerns fails deep
  # inside a metadata save instead of on its first request.
  def atlas_class
    raise NotImplementedError, "#{self.class.name} must declare atlas_resource"
  end
end
