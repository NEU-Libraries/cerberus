# frozen_string_literal: true

require 'rails_helper'

# Genre / category landing — the homepage Featured-Content gateway destination.
# A gated Blacklight browse scoped to a single genre_ssim facet, wrapped in a
# heading well (parity with the People landing). The search runs against test
# Solr (which may hold no items in the genre), so these smoke-test the chrome:
# the heading well names the genre, and the active facet renders as a constraint.
RSpec.describe 'Genres', type: :request do
  describe 'GET /genres' do
    it 'renders a category landing with a heading well naming the genre' do
      get genre_path(f: { genre_ssim: ['Datasets'] })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Datasets') # heading well title
      expect(response.body).to include('Featured content in Datasets.')
    end

    it 'shows the active genre as a constraint chip' do
      get genre_path(f: { genre_ssim: ['Datasets'] })

      expect(response.body).to include('search-results-header__constraints')
    end

    it 'handles a bare visit with no genre selected' do
      get genre_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Browse by category')
    end
  end
end
