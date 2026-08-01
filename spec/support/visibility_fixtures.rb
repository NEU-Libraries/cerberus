# frozen_string_literal: true

# Atlas refuses a resource more visible than its container, so a fixture that
# wants a public Work has to widen the Collection and Community above it first.
# Before that rule existed the ordering didn't matter and most fixtures set the
# leaf public on its own; those writes are now refused
# (AtlasRb::PermissionsError, `visibility_exceeds_parent`).
#
# Widening runs TOP-DOWN — each step keeps child ⊆ parent true, because a
# container is widened before anything under it. A narrowing cascade has to run
# the other way, bottom-up, for the same reason.
module VisibilityFixtures
  # Widen the containers above a resource, outermost first. Both are optional so
  # a spec can pass whichever it has in scope.
  def publicize_ancestry!(community: nil, collection: nil, nuid: '000000004')
    publicize_resource!(AtlasRb::Community, community, nuid) if community
    publicize_resource!(AtlasRb::Collection, collection, nuid) if collection
  end

  # Adds `public` to the read ACL, carrying the existing grants through. The
  # metadata endpoint REPLACES the ACL rather than merging it, so writing a bare
  # `read` would silently drop the edit groups a spec had just granted — the
  # editor then loses access to the very page under test.
  def publicize_resource!(klass, resource, nuid)
    current = AtlasRb::Resource.permissions(resource.id, nuid: nuid)
    klass.metadata(
      resource.id,
      { 'permissions' => { 'read' => (Array(current&.read) + ['public']).uniq,
                           'edit' => Array(current&.edit) } },
      nuid: nuid
    )
  end
end

RSpec.configure do |config|
  config.include VisibilityFixtures
end
