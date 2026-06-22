# frozen_string_literal: true

# Featured-Content category landing — the destination of the homepage gateways.
# Featured Content is *curated*, not a raw genre facet: the page shows the works
# deliberately published into a category's showcases (the linked-member edge),
# resolved across every community by FeaturedCategory. The category rides a plain
# `category` param (named in a heading well); a legacy `f[genre_ssim]` link still
# resolves so old bookmarks don't break.
#
# Inherits CatalogController for the gated search_service. search_action_url keeps
# the embedded search-within / pagination links on this surface (carrying the
# category) rather than escaping to the global catalog.
class GenresController < CatalogController
  def show
    @genre = params[:category].presence || Array(params.dig(:f, :genre_ssim)).first
    @response = FeaturedCategory.call(scope: self, label: @genre, search_state: search_state)
  end

  # Keep the embedded search's search-within / pagination links on the category
  # surface (preserving the category) instead of routing to the global catalog.
  def search_action_url(options = {})
    options = options.to_h if options.is_a?(Blacklight::SearchState)
    url_for(options.reverse_merge(controller: 'genres', action: 'show', category: @genre))
  end
end
