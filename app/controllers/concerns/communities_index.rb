# frozen_string_literal: true

# The /communities index: the inherited Blacklight index, scoped to Communities.
# See docs/discovery.md ("Scoping the index").
module CommunitiesIndex
  extend ActiveSupport::Concern

  # Scope the inherited Blacklight index to Communities, on :index alone.
  # Without it /communities lists every resource type; applied to :show it would
  # strip the child Collections find_children has to surface.
  def search_service_context
    return super unless action_name == 'index'

    super.merge(resource_type_scope: 'Community')
  end
end
