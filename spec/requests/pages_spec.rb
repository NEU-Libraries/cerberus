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

    # The communities index, not the root community: a visitor browses the
    # communities themselves, whatever the root is called or numbered.
    it 'offers a Communities gateway into the communities index' do
      expect(response.body).to include("href=\"#{communities_path}\"")
      expect(response.body).to match(/featured-gateway__label">Communities</)
    end

    # One person for Faculty & Staff, a group for Communities: each gateway's
    # icon is the one heading the page it opens.
    it 'gives Faculty & Staff a single-person icon and Communities a group icon' do
      gateways = response.parsed_body.css('a.featured-gateway').to_h do |a|
        [a.at_css('.featured-gateway__label').text, a.at_css('i')['class'].split]
      end
      expect(gateways['Faculty & Staff']).to include('fa-user')
      expect(gateways['Communities']).to include('fa-users')
    end

    # Nine gateways fill three rows of three; a phone gets a single column.
    it 'lays the nine gateways out in three columns, and one on a phone' do
      grid = response.parsed_body.at_css('section[aria-labelledby="featured-content-heading"] .row')
      expect(grid['class'].split).to include('row-cols-1', 'row-cols-md-3')
      expect(grid.css('.featured-gateway').size).to eq(9)
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

  describe 'GET /terms' do
    it 'links the homepage to the terms' do
      get root_path
      expect(response.body).to include(%(href="#{terms_path}"))
    end

    it 'shows the Introduction to anyone, signed in or not' do
      get terms_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Policies and Terms of Participation',
                                       'These terms do not request or require transfer of copyright to DRS.')
    end

    # The full text is a Work the library revises in the DRS, so its address is
    # configuration, and a stack without that Work shows no dead link.
    it 'links the full document only when its address is configured' do
      get terms_path
      expect(response.body).not_to include('Read the full document')

      allow(Rails.application.config.x.cerberus).to receive(:terms_document_url)
        .and_return('https://hdl.handle.net/2047/terms')
      get terms_path
      expect(response.body).to include('Read the full document', 'href="https://hdl.handle.net/2047/terms"')
    end
  end
end
