# frozen_string_literal: true

# A collection or community page searched with an empty box lists everything
# beneath it, as a keyword search does. See docs/discovery.md ("An empty search
# covers the whole tree").
module WholeTreeSearch
  extend ActiveSupport::Concern

  # The chip naming the whole-tree listing, by the controller serving the page.
  WHOLE_TREE_KINDS = { 'collections' => 'collection', 'communities' => 'community' }.freeze

  MATCH_ALL_QUERY = /\A[\s*:]*\z/

  included do
    helper_method :whole_tree_label
  end

  private

    # A q in the URL, blank or not, is a search. Blacklight drops only nil
    # params, so a blank q rides every facet, sort and page link built from the
    # state; testing present? here would send page 2 back to direct members.
    # A query that matches everything is for signed-in users only: from the root
    # community it lists the whole repository, an enumeration path for scrapers.
    def subtree_search?
      params.key?(:q) && (user_signed_in? || !match_all_query?)
    end

    # Blank, or only stars and colons: edismax answers "*" and "*:*" with
    # every document, so they enumerate as a blank box does.
    def match_all_query?
      params[:q].to_s.match?(MATCH_ALL_QUERY)
    end

    # Only for a blank q: a keyword already shows as its own chip.
    def whole_tree_label
      return unless action_name == 'show' && subtree_search? && params[:q].blank?

      kind = WHOLE_TREE_KINDS[controller_name]
      "Everything in this #{kind}" if kind
    end
end
