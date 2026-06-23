# frozen_string_literal: true

require 'rails_helper'

describe CollectionsController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml', nuid: '000000004') }

  describe 'edit' do
    render_views

    let(:user) { User.new(email: 'test@example.com', password: 'password', groups: ['editors']) }

    before do
      AtlasRb::Collection.metadata(collection.id, { 'permissions' => { 'edit' => ['editors'] } }, nuid: '000000004')
      sign_in user
    end

    it 'renders the edit partial' do
      get :edit, params: { id: collection.id }
      expect(response).to render_template('collections/edit')
      expect(CGI.unescapeHTML(response.body)).to include(collection.title)
    end

    context 'audit history tab' do
      let(:history_envelope) do
        AtlasRb::Mash.new('resource_id' => collection.id, 'events' => [])
      end
      let(:admin_user) do
        User.new(email: 'admin@example.com', nuid: '000000004', groups: [], role: 'admin')
      end

      before do
        allow(AtlasRb::Resource).to receive(:history).and_return(history_envelope)
      end

      it 'renders the History tab for Atlas :admin users (no group stuffing required)' do
        sign_in admin_user
        get :edit, params: { id: collection.id }
        expect(response.body).to match(/<button[^>]*id="history-tab"/)
        expect(response.body).to include('Audit log')
      end

      it 'does not render the History tab for non-admin editors' do
        get :edit, params: { id: collection.id }
        expect(response.body).not_to match(/<button[^>]*id="history-tab"/)
        expect(response.body).not_to include('Audit log')
      end
    end
  end

  describe 'show' do
    render_views

    before do
      AtlasRb::Collection.metadata(collection.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
    end

    it 'renders the show partial' do
      get :show, params: { id: collection.id }
      expect(response).to render_template('collections/show')
      expect(CGI.unescapeHTML(response.body)).to include(collection.title)
    end

    context 'embedded facet search stays scoped to the show page (ShowScopedSearch)' do
      it 'builds facet/search URLs against the collection show action, not the catalog index' do
        get :show, params: { id: collection.id }

        url = controller.search_action_url('f' => { 'type_ssim' => ['Work'] })

        # Scoped to /collections/:id (the show page), carrying the facet —
        # not /catalog and not the index route /collections?f[...].
        expect(url).to include("/collections/#{collection.id}")
        expect(url).to include('type_ssim')
        expect(url).not_to match(%r{/catalog})
      end
    end

    context 'scoped "Search this collection" box' do
      it 'renders a keyword search form targeting the collection show page' do
        get :show, params: { id: collection.id, q: 'anything' }

        expect(response.body).to include('Search this collection')
        # The form GETs back to /collections/:id so find_children narrows
        # this collection's children rather than escaping to /catalog.
        expect(response.body).to match(
          %r{<form[^>]*action="/collections/#{collection.id}"[^>]*method="get"}
        )
      end
    end

    # collection ── sub_collection ── work ("What's New"), i.e. the Work sits
    # two tiers below the anchor collection, beneath a direct-child collection.
    context 'deep scoped search reaches Works nested below direct children' do
      let!(:sub_collection) do
        c = AtlasRb::Collection.create(collection.id,
                                       '/home/cerberus/web/spec/fixtures/files/collection-mods.xml', nuid: '000000004')
        AtlasRb::Collection.metadata(c.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
        c
      end
      let!(:work) do
        w = AtlasRb::Work.create(sub_collection.id,
                                 '/home/cerberus/web/spec/fixtures/files/work-mods.xml', nuid: '000000004')
        AtlasRb::Work.complete(w.id, nuid: '000000004')
        AtlasRb::Work.metadata(w.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
        w
      end

      it 'surfaces the nested Work when a keyword query is present' do
        get :show, params: { id: collection.id, q: "What's New" }

        ids = assigns(:response).documents.map(&:id)
        expect(ids).to include(work.valkyrie_id)
      end

      it 'lists only direct children — not the nested Work — when no query is present' do
        get :show, params: { id: collection.id }

        ids = assigns(:response).documents.map(&:id)
        expect(ids).to include(sub_collection.valkyrie_id)
        expect(ids).not_to include(work.valkyrie_id)
      end
    end
  end

  describe 'new' do
    it 'assigns a open struct to collection' do
      get :new
      expect(assigns(:collection)).to be_a(OpenStruct)
    end

    it 'renders the new partial' do
      get :new
      expect(response).to render_template('collections/new')
    end
  end

  describe 'tombstone' do
    let(:user) do
      User.new(email: 'staff@example.com', nuid: '000000002',
               groups: [Permissions::STAFF_EDIT_GROUP])
    end

    before do
      AtlasRb::Collection.metadata(collection.id,
                                   { 'permissions' => { 'edit' => [Permissions::STAFF_EDIT_GROUP] } }, nuid: '000000004')
      sign_in user
    end

    it 'calls AtlasRb::Collection.tombstone with the acting user nuid and redirects' do
      allow(AtlasRb::Collection).to receive(:tombstone)
      post :tombstone, params: { id: collection.id }
      expect(AtlasRb::Collection).to have_received(:tombstone).with(collection.id)
      expect(subject).to redirect_to(root_path)
    end
  end

  describe 'create' do
    let(:user) { User.new(email: 'creator@example.com', nuid: '000000004', groups: ['editors']) }

    before { sign_in user }

    it 'seeds the new collection title + description via the structure-safe MODS merge (not plain_title=)' do
      post :create, params: { parent_id:  community.id,
                              collection: { title: 'BrandNewCollection', description: 'CollectionAbstract' } }

      created_id = response.location.split('/').last
      created = AtlasRb::Collection.find(created_id)
      expect(created.title).to eq('BrandNewCollection')
      expect(created.description).to include('CollectionAbstract')
    ensure
      AtlasRb::Collection.tombstone(created_id) if created_id
    end
  end

  # The personal-workspace trail is isolated on the private seam (the show stack
  # makes many Atlas calls; here we stub the resolve + find and assert the crumbs).
  describe '#collection_breadcrumbs (private)' do
    def stub_collection(parent_noid:)
      item = OpenStruct.new(id: 'cnoid', title: 'Working Files',
                            ancestor_chain: [{ 'noid' => 'people', 'klass' => 'Community', 'title' => 'People' },
                                             { 'noid' => parent_noid, 'klass' => 'Collection', 'title' => 'Personal Root' }])
      allow(AtlasRb::Resource).to receive(:find).with('cnoid').and_return(OpenStruct.new(resource: item, klass: 'Collection'))
    end

    it 'trails "My DRS" for the owner viewing a collection under their own personal root' do
      stub_collection(parent_noid: 'janeroot')
      allow(controller).to receive(:deposit_person).and_return(AtlasRb::Mash.new('personal_root_id' => 'janeroot'))

      expect(controller).to receive(:breadcrumb).with('My DRS', my_drs_path)
      expect(controller).to receive(:add_breadcrumb_for).with('cnoid', 'Collection', 'Working Files')
      expect(controller).not_to receive(:breadcrumbs)

      controller.send(:collection_breadcrumbs, 'cnoid')
    end

    it 'trails "People / <Person>" for the public view of a workspace collection' do
      stub_collection(parent_noid: 'janeroot')
      allow(controller).to receive(:deposit_person).and_return(nil) # logged out / non-owner
      root_doc = SolrDocument.new('id' => 'uuid-jr', 'personal_root_bsi' => true, 'depositor_ssi' => '000000002')
      allow(controller).to receive(:collection_doc).with('janeroot').and_return(root_doc)
      allow(AtlasRb::Person).to receive(:resolve).with(['000000002'])
                                                 .and_return([AtlasRb::Mash.new('id' => 'jnoid', 'display_name' => 'Jane Doe')])

      expect(controller).to receive(:breadcrumb).with('People', people_path)
      expect(controller).to receive(:breadcrumb).with('Jane Doe', person_path('jnoid'))
      expect(controller).to receive(:add_breadcrumb_for).with('cnoid', 'Collection', 'Working Files')
      expect(controller).not_to receive(:breadcrumbs)

      controller.send(:collection_breadcrumbs, 'cnoid')
    end

    it 'falls back to the structural trail for an ordinary (non-workspace) collection' do
      stub_collection(parent_noid: 'a-community')
      allow(controller).to receive(:deposit_person).and_return(nil)
      ordinary = SolrDocument.new('id' => 'uuid-x', 'personal_root_bsi' => false)
      allow(controller).to receive(:collection_doc).with('a-community').and_return(ordinary)

      expect(controller).to receive(:breadcrumbs).with('cnoid', editing: false, result: anything)
      expect(controller).not_to receive(:breadcrumb).with('My DRS', anything)

      controller.send(:collection_breadcrumbs, 'cnoid')
    end

    it 'keeps the "My DRS" prefix and uses the edit tail when editing an owner-workspace collection' do
      stub_collection(parent_noid: 'janeroot')
      allow(controller).to receive(:deposit_person).and_return(AtlasRb::Mash.new('personal_root_id' => 'janeroot'))

      expect(controller).to receive(:breadcrumb).with('My DRS', my_drs_path)
      expect(controller).to receive(:edit_breadcrumb_tail).with(anything, 'Collection')
      expect(controller).not_to receive(:add_breadcrumb_for)
      expect(controller).not_to receive(:breadcrumbs)

      controller.send(:collection_breadcrumbs, 'cnoid', editing: true)
    end

    it 'passes editing through to the structural trail for an ordinary collection edit' do
      stub_collection(parent_noid: 'a-community')
      allow(controller).to receive(:deposit_person).and_return(nil)
      ordinary = SolrDocument.new('id' => 'uuid-x', 'personal_root_bsi' => false)
      allow(controller).to receive(:collection_doc).with('a-community').and_return(ordinary)

      expect(controller).to receive(:breadcrumbs).with('cnoid', editing: true, result: anything)

      controller.send(:collection_breadcrumbs, 'cnoid', editing: true)
    end
  end
end
