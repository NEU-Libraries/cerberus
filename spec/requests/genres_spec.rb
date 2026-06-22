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
end
