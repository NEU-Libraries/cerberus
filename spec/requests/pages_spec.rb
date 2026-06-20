# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pages', type: :request do
  describe 'GET / (home)' do
    before { get root_path }

    it 'renders the homepage' do
      expect(response).to have_http_status(:ok)
    end

    it 'surfaces the Featured Content gateway section' do
      expect(response.body).to include('Featured Content')
      expect(response.body).to include('featured-gateway')
    end

    it 'links each scholarly category into its genre landing' do
      # Canned, v1-faithful wayfinding: a genre gateway opens the genre landing
      # (a heading-welled browse) with genre_ssim as a constraint.
      expect(response.body).to include(CGI.escapeHTML(
                                         genre_path(f: { genre_ssim: ['Research Publications'] })
                                       ))
    end

    it 'offers a Faculty & Staff gateway into the People directory' do
      expect(response.body).to include('Faculty &amp; Staff')
      expect(response.body).to include("href=\"#{people_path}\"")
    end
  end
end
