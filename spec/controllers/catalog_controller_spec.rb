# frozen_string_literal: true

require 'rails_helper'

describe CatalogController do
  let!(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', nuid: '000000004') }

  describe 'index' do
    render_views
    it 'renders the index partial' do
      AtlasRb::Community.metadata(community.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
      expect(community.title).to eq('Northeastern University')
      get :index
      expect(response).to render_template('catalog/index')
      expect(CGI.unescapeHTML(response.body)).to include(community.title)
    end

    it 'overlays a resource-type pill on each result thumbnail' do
      AtlasRb::Community.metadata(community.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
      get :index
      expect(response.body).to include('class="thumb-type-pill">Community')
    end
  end
end
