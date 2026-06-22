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

    it 'labels a featured showcase Collection "Featured" in the standard pill (no special styling)' do
      collection = AtlasRb::Collection.create(community.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml',
                                              featured: true, nuid: '000000004')
      AtlasRb::Collection.metadata(collection.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
      get :index
      expect(response.body).to include('class="thumb-type-pill">Featured')
      expect(response.body).not_to include('thumb-type-pill--featured')
    end
  end

  describe 'facets' do
    # The "Content" facet rides Atlas's classification_ssim projection (the
    # ClassificationIndexer rolls each Work's FileSet Classifications onto the
    # Work doc). Config-level assertion is deterministic here; rendering with
    # real values is verified in-browser against Atlas-indexed content (the
    # test env can't deposit classified FileSets to populate the field).
    it 'surfaces a "Content" facet over the projected classification_ssim field' do
      field = described_class.blacklight_config.facet_fields['classification_ssim']
      expect(field).to be_present
      expect(field.label).to eq('Content')
    end
  end
end
