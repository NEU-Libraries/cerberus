# frozen_string_literal: true

require 'rails_helper'

describe CatalogController do
  let!(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', nuid: '000000004') }

  def public_work(parent_id, fixture)
    AtlasRb::Work.create(parent_id, fixture_mods(fixture), nuid: '000000004').tap do |work|
      AtlasRb::Work.complete(work.id, nuid: '000000004')
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
    end
  end

  def fixture_mods(kind) = Rails.root.join('spec/fixtures/files', "#{kind}-mods.xml").to_s

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
      publicize_ancestry!(community: community)
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

    it 'labels an embargoed work "Embargoed" in the red pill variant, ahead of Featured' do
      get :index
      doc = SolrDocument.new('id' => 'w1', 'internal_resource_tesim' => ['Work'], 'featured_bsi' => true,
                             'embargo_release_date_dtsi' => (Date.current + 30).to_s)

      html = controller.view_context.iiif_thumbnail(doc)

      expect(html).to include('>Embargoed</span>')
      expect(html).to include('thumb-type-pill--embargoed')
    end
  end

  # Every field the config names has to be one Atlas actually writes. Blacklight
  # renders no section for a field with no values, so a config over a dead field
  # is silent — no error, no empty heading, just a facet or a metadata row that
  # never appears. Only a query against a real corpus catches that, so this runs
  # against the test Atlas + Solr rather than asserting the config strings.
  describe 'field coverage' do
    # A field the config may name while the test corpus carries no value for it,
    # mapped to the reason. Keep it short: every entry is a field this spec
    # cannot vouch for.
    let(:unprovable_in_test) do
      { 'classification_ssim' => 'projected from a FileSet Classification, and the test env deposits none' }
    end

    let!(:collection) do
      publicize_ancestry!(community: community)
      AtlasRb::Collection.create(community.id, fixture_mods('collection'), nuid: '000000004').tap do |created|
        AtlasRb::Collection.metadata(created.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
      end
    end

    it 'names only fields the index carries' do
      work = public_work(collection.id, 'work')

      expect(unindexed_configured_fields).to be_empty
    ensure
      AtlasRb::Work.tombstone(work.id) if work
      AtlasRb::Collection.tombstone(collection.id)
    end

    def configured_fields
      config = described_class.blacklight_config
      (config.facet_fields.keys + config.index_fields.keys + config.show_fields.keys).uniq
    end

    def unindexed_configured_fields
      (configured_fields - unprovable_in_test.keys).reject do |field|
        Blacklight.default_index.search(q: "#{field}:*", rows: 0).total.positive?
      end
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

    # Assert the values Blacklight renders, not the config strings. A facet over
    # an empty field renders no section at all, so a config-only assertion is
    # green while the sidebar shows nothing.
    render_views

    it 'renders the Creator and Topic facets with the values Atlas indexed' do
      publicize_ancestry!(community: community)
      collection = AtlasRb::Collection.create(community.id, fixture_mods('collection'), nuid: '000000004')
      AtlasRb::Collection.metadata(collection.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
      work = public_work(collection.id, 'work')

      get :index, params: { q: "What's New" }

      body = CGI.unescapeHTML(response.body)
      expect(body).to include('id="facet-creator_ssim"').and include('Cohen, Daniel J.')
      expect(body).to include('id="facet-subject_ssim"').and include('Civil society')
    ensure
      AtlasRb::Work.tombstone(work.id) if work
      AtlasRb::Collection.tombstone(collection.id) if collection
    end
  end

  # Every sort clause must name a field Atlas indexes as single-valued. Solr does
  # not error on a sort over a field no document carries: it finds the value
  # missing on every document and returns index order, so a clause naming the
  # wrong field silently does nothing and two different sorts produce the same
  # list. Only ordering real documents catches that, so these run against the
  # test Atlas + Solr rather than asserting the config strings.
  describe 'sort' do
    # Two Works whose title, creator and origin date disagree with each other:
    # "Reflections on a Still Lake" (Rivera, 2026) sorts ahead of "What's New"
    # (Cohen, 2017) by title and by date, behind it by creator. One pair
    # therefore proves each field is live, and carries all four sort fields for
    # the coverage example.
    let(:collection) do
      publicize_ancestry!(community: community)
      AtlasRb::Collection.create(community.id, fixture_mods('collection'), nuid: '000000004').tap do |created|
        AtlasRb::Collection.metadata(created.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
      end
    end

    # "What's New" is deposited first, so the pair's index order is the reverse
    # of the expected title order. A sort over a field no document carries falls
    # back to index order, so each assertion below that contradicts the deposit
    # order fails on a dead field instead of passing by coincidence.
    it 'orders results on the field each sort names' do
      whats_new = public_work(collection.id, 'work')
      lake = public_work(collection.id, 'work-lake')
      pair = [lake, whats_new].map(&:valkyrie_id)

      expect(order_under('title', pair)).to eq([lake.valkyrie_id, whats_new.valkyrie_id])
      expect(order_under('creator', pair)).to eq([whats_new.valkyrie_id, lake.valkyrie_id])
      expect(order_under('creator-desc', pair)).to eq([lake.valkyrie_id, whats_new.valkyrie_id])
      expect(order_under('date-created', pair)).to eq([lake.valkyrie_id, whats_new.valkyrie_id])
    ensure
      [lake, whats_new].compact.each { |work| AtlasRb::Work.tombstone(work.id) }
      AtlasRb::Collection.tombstone(collection.id)
    end

    it 'names only fields the index carries' do
      lake = public_work(collection.id, 'work-lake')

      expect(unindexed_sort_fields).to be_empty
    ensure
      AtlasRb::Work.tombstone(lake.id) if lake
      AtlasRb::Collection.tombstone(collection.id)
    end

    # The other way to get a sort wrong, and it fails louder: Solr rejects a sort
    # over a multi-valued field outright, so the results page errors instead of
    # mis-ordering. The Solr dynamic-field suffixes end in `m` when multi-valued
    # (title_tsim, creator_ssim), so the suffix alone rules a candidate out —
    # no document needed, unlike the coverage example above.
    it 'names no multi-valued field' do
      expect(sort_fields).to all(satisfy { |field| !field.end_with?('m') })
    end

    # The single-valued field each clause sorts on, minus `score` (which Solr
    # computes per query and no document stores).
    def sort_fields
      described_class.blacklight_config.sort_fields.values
                     .flat_map { |field| field.sort.split(',') }
                     .map { |clause| clause.strip.split(/\s+/).first }
                     .uniq - ['score']
    end

    def unindexed_sort_fields
      sort_fields.reject { |field| Blacklight.default_index.search(q: "#{field}:*", rows: 0).total.positive? }
    end

    # The ids in the order one configured sort returns them, restricted to the
    # pair so the seeded corpus cannot pad the result.
    def order_under(sort_key, ids)
      clause = described_class.blacklight_config.sort_fields.fetch(sort_key).sort
      Blacklight.default_index.search(
        q: '*:*', sort: clause, rows: ids.length,
        fq: "id:(#{ids.map { |id| %("#{id}") }.join(' OR ')})"
      ).documents.map(&:id)
    end
  end
end
