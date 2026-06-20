# frozen_string_literal: true

# Genre / scholarly-category landing — the destination of the homepage "Featured
# Content" gateways. A thin wrapper over the gated Blacklight browse: the genre
# rides the standard `f[genre_ssim][]` facet param (already set by the gateway
# link), so the active filter renders as a constraint chip exactly like any
# catalog facet. This controller's only job is to name the category in a heading
# well, bringing the gateway destinations to parity with the People landing.
#
# Inherits CatalogController for the gated search_service. search_action_url keeps
# the embedded facet / search-within / pagination links on the genre surface
# rather than escaping to the global catalog.
class GenresController < CatalogController
  def show
    @genre = Array(params.dig(:f, :genre_ssim)).first
    builder = search_service.search_builder.with(search_state)
    @response = Blacklight.default_index.search(builder)
  end

  # Keep the embedded search's facet / search-within / pagination links on the
  # genre surface instead of routing them to the global catalog.
  def search_action_url(options = {})
    options = options.to_h if options.is_a?(Blacklight::SearchState)
    url_for(options.reverse_merge(controller: 'genres', action: 'show'))
  end
end
