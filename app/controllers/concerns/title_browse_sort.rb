# frozen_string_literal: true

# Lists by title when nobody has searched or picked a sort, on the actions an
# includer names. See docs/discovery.md ("Browsing by title").
module TitleBrowseSort
  extend ActiveSupport::Concern

  included do
    class_attribute :title_browse_actions, instance_writer: false, default: []
  end

  class_methods do
    def title_browse_on(*actions)
      self.title_browse_actions = actions.map(&:to_s)
    end
  end

  private

    # Read by SearchState#sort_field only when the request names no sort.
    # Without a query relevance has nothing to rank, so its tie-break would list
    # the newest items first.
    def browse_sort_key(state)
      'title' if title_browse_actions.include?(action_name) && state.query_param.blank?
    end
end
