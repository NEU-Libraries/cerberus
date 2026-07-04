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

    it 'excludes featured showcase Collections from the global index but keeps ordinary ones' do
      featured = AtlasRb::Collection.create(community.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml',
                                            featured: true, nuid: '000000004')
      AtlasRb::Collection.metadata(featured.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
      ordinary = AtlasRb::Collection.create(community.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml',
                                            nuid: '000000004')
      AtlasRb::Collection.metadata(ordinary.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')

      get :index

      ids = assigns(:response).documents.map(&:id)
      expect(ids).to include(ordinary.valkyrie_id)     # ordinary public collection is in general search
      expect(ids).not_to include(featured.valkyrie_id) # the showcase is not
    ensure
      AtlasRb::Collection.tombstone(featured.id) if featured
      AtlasRb::Collection.tombstone(ordinary.id) if ordinary
    end

    # The "Featured" pill still renders for showcases where they *do* appear
    # (a community browse / find_children) — verified via the shared helper, as
    # the global index now excludes them.
    it 'labels a featured collection "Featured" in the standard pill via the thumbnail helper' do
      get :index # establishes a view context
      doc = SolrDocument.new('id' => 'c1', 'internal_resource_tesim' => ['Collection'], 'featured_bsi' => true)

      html = controller.view_context.iiif_thumbnail(doc)

      expect(html).to include('>Featured</span>')
      expect(html).not_to include('thumb-type-pill--featured')
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
