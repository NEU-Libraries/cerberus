# frozen_string_literal: true

# The /communities index: the inherited Blacklight index, scoped to Communities
# and sorted by name. See docs/discovery.md ("Scoping the index").
module CommunitiesIndex
  extend ActiveSupport::Concern

  # Scope the inherited Blacklight index to Communities, on :index alone.
  # Without it /communities lists every resource type; applied to :show it would
  # strip the child Collections find_children has to surface.
  def search_service_context
    return super unless action_name == 'index'

    super.merge(resource_type_scope: 'Community')
  end

  # Browsed by name, as v1's index was. With no query, relevance has nothing to
  # rank, so it would list communities in the order they were made. The default
  # goes in where Blacklight builds the state: it memoizes that state before the
  # action runs, so setting params[:sort] inside #index comes too late.
  def search_state
    @search_state ||= begin
      state = search_state_class.new(params, blacklight_config, self)
      title_by_default?(state) ? state.reset(state.to_h.merge(sort: 'title')) : state
    end
  end

  private

    def title_by_default?(state)
      action_name == 'index' && state.to_h[:q].blank? && state.to_h[:sort].blank?
    end
end
