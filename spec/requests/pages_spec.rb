# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pages', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:standard_user) do
    User.new(email: 'standard@example.com', password: 'password',
             nuid: '000000005', role: 'standard', groups: [])
  end

  describe 'GET / (home)' do
    before { get root_path }

    it 'renders the homepage' do
      expect(response).to have_http_status(:ok)
    end

    it 'surfaces the Featured Content gateway section' do
      expect(response.body).to include('Featured Content')
      expect(response.body).to include('featured-gateway')
    end

    it 'links each scholarly category into its Featured-Content landing' do
      # Canned, v1-faithful wayfinding: a genre gateway opens the category's
      # Featured-Content landing (works curated into its showcases), via the
      # `category` param — not the raw genre_ssim facet.
      expect(response.body).to include(CGI.escapeHTML(genre_path(category: 'Research Publications')))
    end

    it 'offers a Faculty & Staff gateway into the People directory' do
      expect(response.body).to include('Faculty &amp; Staff')
      expect(response.body).to include("href=\"#{people_path}\"")
    end

    it 'surfaces the Recently Added Items section' do
      # The grid is driven by a gated query over the newest Works; its contents
      # are render-smoke-tested here (test Solr is nondeterministic) and the live
      # newest-Works-per-visitor path is verified in the browser.
      expect(response.body).to include('Recently Added Items')
    end
  end

  describe 'GET / (home) signed in' do
    it 'renders cleanly for a signed-in user (gated recent-works query runs)' do
      sign_in standard_user

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Recently Added Items')
    end
  end
end
