# frozen_string_literal: true

require 'rails_helper'

# Featured-Content category landing — the homepage gateway destination. Featured
# Content is curated: the page shows the works published into a category's
# showcases (FeaturedCategory over the linked-member edge), not a genre-facet
# browse. The membership query runs against test Solr (which may hold no curated
# works for the category), so these smoke-test the chrome: the heading well names
# the category, and a bare visit degrades gracefully.
RSpec.describe 'Genres', type: :request do
  describe 'GET /genres' do
    it 'renders a category landing with a heading well naming the category' do
      get genre_path(category: 'Datasets')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Datasets') # heading well title
      expect(response.body).to include('Featured content in Datasets.')
    end

    it 'still resolves a legacy genre_ssim facet link' do
      get genre_path(f: { genre_ssim: ['Datasets'] })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Featured content in Datasets.')
    end

    it 'handles a bare visit with no category selected' do
      get genre_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Browse by category')
    end
  end

  # Regression: switching the view (list/grid) on a category landing used to drop
  # the `category` param and empty the page. The view-type toggle builds its URL
  # from search_state.to_h, and Blacklight's permit_search_params strips any param
  # not in search_state_fields — so `category` must be retained there.
  describe 'category param retention in the search state' do
    it 'keeps category in search_state.to_h so view-toggle links preserve the genre' do
      state = SearchState.new(
        ActionController::Parameters.new(category: 'Datasets', controller: 'genres', action: 'show'),
        CatalogController.blacklight_config
      )

      expect(state.to_h).to include('category' => 'Datasets')
    end

    it 'still resolves the category after a view switch (no empty page)' do
      get genre_path(category: 'Datasets', view: 'list')

      expect(response).to have_http_status(:ok)
      # The category resolved (heading well names it) rather than degrading to the
      # bare "Browse by category" landing that a dropped param produced.
      expect(response.body).to include('Featured content in Datasets.')
    end
  end
end
