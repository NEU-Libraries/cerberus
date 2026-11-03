# frozen_string_literal: true

# Keeps a query that matches everything from listing the whole repository to an
# anonymous visitor. See docs/discovery.md ("Match-all queries are for
# signed-in users").
module AnonymousMatchAll
  extend ActiveSupport::Concern

  # Blank, or only stars and colons: edismax answers "*" and "*:*" with every
  # document, so they list everything just as a blank or missing q does.
  MATCH_ALL_QUERY = /\A[\s*:]*\z/

  included do
    # The catalog's own index only. Its subclasses inherit #index for their
    # public listings (/communities, /collections, genres), which must stay open.
    before_action :refuse_anonymous_match_all, only: :index, if: -> { controller_name == 'catalog' }
  end

  private

    def match_all_query?
      params[:q].to_s.match?(MATCH_ALL_QUERY)
    end

    # A facet still lists a slice, and a work's metadata links depend on that,
    # so only the unfiltered listing is refused.
    def refuse_anonymous_match_all
      return if user_signed_in? || !match_all_query? || search_state.filters.any?

      render template: 'errors/forbidden', status: :forbidden, layout: 'application', formats: [:html]
    end
end
