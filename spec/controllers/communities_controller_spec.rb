# frozen_string_literal: true

require 'rails_helper'

describe CommunitiesController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', nuid: '000000004') }

  describe 'edit' do
    render_views

    let(:user) { User.new(email: 'test@example.com', password: 'password', groups: ['editors']) }

    before do
      AtlasRb::Community.metadata(community.id, { 'permissions' => { 'edit' => ['editors'] } }, nuid: '000000004')
      sign_in user
    end

    it 'renders the edit partial' do
      get :edit, params: { id: community.id }
      expect(response).to render_template('communities/edit')
      expect(CGI.unescapeHTML(response.body)).to include(community.title)
    end

    it 'renders breadcrumbs: an active "Edit Community" crumb, the title linking back to show, no Add affordance' do
      get :edit, params: { id: community.id }
      expect(response.body).to include('aria-label="breadcrumb"')
      expect(response.body).to include('Edit Community') # you-are-here crumb
      expect(response.body).to include(%(href="#{community_path(community.id)}")) # title links to show
      expect(response.body).not_to include('breadcrumb-add') # Add dropdown suppressed on edit
    end

    context 'audit history tab' do
      let(:history_envelope) do
        AtlasRb::Mash.new('resource_id' => community.id, 'events' => [])
      end
      let(:admin_user) do
        User.new(email: 'admin@example.com', nuid: '000000004', groups: [], role: 'admin')
      end

      before do
        allow(AtlasRb::Resource).to receive(:history).and_return(history_envelope)
      end

      it 'renders the History tab for Atlas :admin users (no group stuffing required)' do
        sign_in admin_user
        get :edit, params: { id: community.id }
        expect(response.body).to match(/<button[^>]*id="history-tab"/)
        expect(response.body).to include('Audit log')
      end

      it 'does not render the History tab for non-admin editors' do
        get :edit, params: { id: community.id }
        expect(response.body).not_to match(/<button[^>]*id="history-tab"/)
        expect(response.body).not_to include('Audit log')
      end
    end
  end

  describe 'show' do
    render_views

    before do
      AtlasRb::Community.metadata(community.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
    end

    it 'renders the show partial' do
      get :show, params: { id: community.id }
      expect(response).to render_template('communities/show')
      expect(CGI.unescapeHTML(response.body)).to include(community.title)
    end

    context 'Add affordance in the breadcrumb' do
      it 'is hidden from anonymous users (TODO: replace with Ability check)' do
        get :show, params: { id: community.id }
        expect(response.body).not_to include('breadcrumb-add')
      end

      it 'is rendered for signed-in users' do
        sign_in User.new(email: 'staff@example.com', nuid: '000000002', groups: ['editors'])
        get :show, params: { id: community.id }
        expect(response.body).to include('breadcrumb-add')
      end
    end

    context 'embedded facet search stays scoped to the show page (ShowScopedSearch)' do
      it 'builds facet/search URLs against the community show action, not the catalog index' do
        get :show, params: { id: community.id }

        url = controller.search_action_url('f' => { 'type_ssim' => ['Collection'] })

        # Scoped to /communities/:id (the show page), carrying the facet —
        # not /catalog and not the index route /communities?f[...].
        expect(url).to include("/communities/#{community.id}")
        expect(url).to include('type_ssim')
        expect(url).not_to match(%r{/catalog})
      end
    end

    context 'scoped "Search this community" box' do
      it 'renders a keyword search form targeting the community show page' do
        get :show, params: { id: community.id, q: 'anything' }

        expect(response.body).to include('Search this community')
        # The form GETs back to /communities/:id so find_children narrows
        # this community's children rather than escaping to /catalog.
        expect(response.body).to match(
          %r{<form[^>]*action="/communities/#{community.id}"[^>]*method="get"}
        )
      end
    end

    # community ── collection ── work ("What's New"), i.e. the Work sits two
    # tiers below the community, beneath a direct-child collection.
    context 'deep scoped search reaches Works nested below direct children' do
      let!(:collection) do
        c = AtlasRb::Collection.create(community.id,
                                       '/home/cerberus/web/spec/fixtures/files/collection-mods.xml', nuid: '000000004')
        AtlasRb::Collection.metadata(c.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
        c
      end
      let!(:work) do
        w = AtlasRb::Work.create(collection.id,
                                 '/home/cerberus/web/spec/fixtures/files/work-mods.xml', nuid: '000000004')
        AtlasRb::Work.complete(w.id, nuid: '000000004')
        AtlasRb::Work.metadata(w.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
        w
      end

      it 'surfaces the nested Work when a keyword query is present' do
        get :show, params: { id: community.id, q: "What's New" }

        ids = assigns(:response).documents.map(&:id)
        expect(ids).to include(work.valkyrie_id)
      end

      it 'lists only direct children — not the nested Work — when no query is present' do
        get :show, params: { id: community.id }

        ids = assigns(:response).documents.map(&:id)
        expect(ids).to include(collection.valkyrie_id)
        expect(ids).not_to include(work.valkyrie_id)
      end
    end
  end

  describe 'show on a nonexistent community id' do
    render_views

    it 'renders the not_found template with status 404' do
      get :show, params: { id: 'does-not-exist-1234' }
      expect(response).to have_http_status(:not_found)
      expect(response).to render_template('errors/not_found')
      expect(CGI.unescapeHTML(response.body)).to include('the community you requested was not found')
    end
  end

  describe 'new' do
    it 'assigns a open struct to community' do
      get :new
      expect(assigns(:community)).to be_a(OpenStruct)
    end

    it 'renders the new partial' do
      get :new
      expect(response).to render_template('communities/new')
    end
  end

  describe 'tombstone' do
    let(:user) do
      User.new(email: 'staff@example.com', nuid: '000000002',
               groups: [Permissions::STAFF_EDIT_GROUP])
    end

    before do
      AtlasRb::Community.metadata(community.id,
                                  { 'permissions' => { 'edit' => [Permissions::STAFF_EDIT_GROUP] } }, nuid: '000000004')
      sign_in user
    end

    it 'calls AtlasRb::Community.tombstone with the acting user nuid and redirects' do
      allow(AtlasRb::Community).to receive(:tombstone)
      post :tombstone, params: { id: community.id }
      expect(AtlasRb::Community).to have_received(:tombstone).with(community.id)
      expect(subject).to redirect_to(root_path)
    end
  end

  describe 'create' do
    let(:user) { User.new(email: 'creator@example.com', nuid: '000000004', groups: ['editors']) }

    before { sign_in user }

    it 'seeds the new community title + description via the structure-safe MODS merge (not plain_title=)' do
      # Provisioning is the ShowcaseProvisioner's job (asserted below); stub it
      # here so this test doesn't mint real showcase collections per run.
      allow(ShowcaseProvisioner).to receive(:call)

      post :create, params: { community: { title: 'BrandNewCommunity', description: 'CommunityAbstract' } }

      created_id = response.location.split('/').last
      created = AtlasRb::Community.find(created_id)
      expect(created.title).to eq('BrandNewCommunity')
      expect(created.description).to include('CommunityAbstract')
    ensure
      AtlasRb::Community.tombstone(created_id) if created_id
    end

    it 'provisions the new community with genre showcases' do
      allow(AtlasRb::Community).to receive(:create).and_return(AtlasRb::Mash.new('id' => 'newcomm'))
      allow_any_instance_of(described_class).to receive(:save_descriptive!) # no MODS writes
      allow(ShowcaseProvisioner).to receive(:call)

      post :create, params: { community: { title: 'X', description: 'Y' } }

      expect(ShowcaseProvisioner).to have_received(:call).with(community_id: 'newcomm')
      expect(response).to redirect_to(community_path('newcomm'))
    end
  end

  # The v1-faithful hide-if-empty gate, unit-tested on the private seam (the full
  # show stack is exercised elsewhere; here we isolate the filtering + facet read).
  describe '#hide_empty_showcases (private)' do
    def doc(id, featured:, title: 'X')
      SolrDocument.new('id' => id, 'featured_bsi' => featured, 'title_tsim' => [title])
    end

    it 'drops empty featured showcases, keeping populated ones and ordinary collections' do
      empty = doc('uuid-empty', featured: true, title: 'Datasets')
      full  = doc('uuid-full',  featured: true, title: 'Presentations')
      plain = doc('uuid-plain', featured: false)
      documents = [empty, full, plain]
      response_double = instance_double(Blacklight::Solr::Response, documents: documents, total: 3,
                                                                    response: { 'numFound' => 3 })
      controller.instance_variable_set(:@response, response_double)
      allow(controller).to receive(:populated_showcase_ids).and_return(Set['uuid-full'])

      controller.send(:hide_empty_showcases)

      expect(documents).to contain_exactly(full, plain)
    end

    it 'is a no-op when the browse has no featured showcases' do
      plain = doc('uuid-plain', featured: false)
      response_double = instance_double(Blacklight::Solr::Response, documents: [plain])
      controller.instance_variable_set(:@response, response_double)

      expect { controller.send(:hide_empty_showcases) }.not_to raise_error
    end
  end

  describe '#populated_showcase_ids (private)' do
    it 'returns the showcase uuids whose member facet count is positive' do
      facet = { MembershipQuery::STRUCTURAL_FIELD => [],
                MembershipQuery::LINKED_FIELD     => ['id-uuid-full', 3, 'id-uuid-empty', 0] }
      search_response = instance_double(Blacklight::Solr::Response)
      allow(search_response).to receive(:dig).with('facet_counts', 'facet_fields').and_return(facet)
      index = instance_double(Blacklight::Solr::Repository, search: search_response)
      allow(Blacklight).to receive(:default_index).and_return(index)

      builder = double('builder')
      allow(builder).to receive(:with).and_return(builder)
      allow(builder).to receive(:with_filters).and_return(builder)
      allow(builder).to receive(:merge).and_return(builder)
      allow(controller).to receive(:search_service).and_return(double(search_builder: builder))

      result = controller.send(:populated_showcase_ids, %w[uuid-full uuid-empty])

      expect(result).to eq(Set['uuid-full'])
    end
  end
end
