# frozen_string_literal: true

# The breadcrumb trail on a Set's page and its Edit page. A Set has no Atlas
# ancestry, so the trail is always My Sets, then the Set.
module SetBreadcrumbs
  extend ActiveSupport::Concern

  included do
    helper_method :set_trail?
  end

  private

    # My Sets needs a set curator, so only a curator gets a trail that starts
    # there. Anyone else reaching a public set sees no trail.
    def set_trail?
      effective_user&.curates_sets?
    end

    # `match: :exclusive` lets a crumb stay current under a search query string,
    # which `:exact` would not, but not on a sub-path such as `/edit`.
    def set_breadcrumbs
      breadcrumb('My Sets', sets_path, match: :exclusive)
      breadcrumb(@set['title'], set_path(@set['id']), match: :exclusive)
    end

    # Mirrors ApplicationController#edit_breadcrumb_tail: a non-link "Edit set"
    # you-are-here after the Set's own trail.
    def edit_breadcrumbs
      set_breadcrumbs
      breadcrumb('Edit set', edit_set_path(@set['id']))
    end
end
