# frozen_string_literal: true

# Which Rails route serves an Atlas resource type, for the sites that learn a
# type at runtime from Atlas or Solr data. See docs/people-and-routing.md.
#
# A controller that knows its own type states its route in `atlas_resource`
# instead, and reads it back as show_path / edit_path.
module AtlasRoutes
  # Stated rather than derived. Downcasing a class name happens to work for
  # every type below, so the map earns its place on `route_for`'s raise instead:
  # an unmapped type says so here rather than assembling a helper name that
  # nothing serves.
  #
  # `Compilation` has no producer today — Atlas's resolver answers 404 for one
  # (Valkyrie-backed types only) and Solr does not index them — so nothing can
  # hand this map that string. Kept because the route is correct if either ever
  # changes, and because it records the vocabulary split: a Compilation is a Set
  # everywhere a reader can see one.
  ROUTES = {
    'Community'   => :community,
    'Collection'  => :collection,
    'Work'        => :work,
    'Compilation' => :set,
    'Person'      => :person
  }.freeze

  # fetch with a raise, never a fallback: an unmapped type must say so here
  # rather than reach public_send with a route helper that does not exist.
  def self.route_for(klass)
    ROUTES.fetch(klass.to_s) { raise ArgumentError, "no DRS route for Atlas type #{klass.inspect}" }
  end
end
