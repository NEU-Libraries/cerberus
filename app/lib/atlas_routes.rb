# frozen_string_literal: true

# Which Rails route serves an Atlas resource type, for the sites that learn a
# type at runtime from Atlas or Solr data. See docs/people-and-routing.md.
#
# A controller that knows its own type states its route in `atlas_resource`
# instead, and reads it back as show_path / edit_path.
module AtlasRoutes
  # Atlas's type vocabulary is not the UI's, so a route name cannot be had by
  # downcasing a class name: a Compilation is a Set everywhere a reader can see
  # one, and there is no compilation_path. This map is where that translation
  # lives.
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
