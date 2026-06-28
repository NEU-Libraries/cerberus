# frozen_string_literal: true

require 'rails_helper'

describe CommunitiesController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', nuid: '000000004') }

  describe 'index' do
    it 'scopes the listing to Communities only — child Collections do not leak in' do
      AtlasRb::Community.metadata(community.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
      collection = AtlasRb::Collection.create(community.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml',
                                              nuid: '000000004')
      AtlasRb::Collection.metadata(collection.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')

      get :index

      ids = assigns(:response).documents.map(&:id)
      expect(ids).to include(community.valkyrie_id)      # the community is listed
      expect(ids).not_to include(collection.valkyrie_id) # a Collection is not
    ensure
      AtlasRb::Collection.tombstone(collection.id) if collection
    end
  end

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

    context 'with affiliated people (synthetic Faculty & Staff row)' do
      before { allow(controller).to receive(:affiliated_people_count).and_return(1) }

      # Regression: the synthetic row was built as SolrDocument.new(hash) with no
      # response back-reference, so Blacklight's per-row highlight check
      # (has_highlight_field? → response['highlighting']) raised
      # "undefined method `[]' for nil" while rendering the document list. The
      # row now shares @response, so the page renders.
      it 'renders the show page with the Faculty & Staff row without a highlight crash' do
        get :show, params: { id: community.id }
        expect(response).to have_http_status(:ok)
        expect(CGI.unescapeHTML(response.body)).to include('Faculty & Staff')
      end

      it 'labels the synthetic row\'s type pill "People" (a browse-to-many), not "Person"' do
        get :show, params: { id: community.id }
        expect(response.body).to include('thumb-type-pill">People')
        expect(response.body).not_to include('thumb-type-pill">Person')
      end
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

    context 'Edit affordance is gated on the :edit ability' do
      it 'is hidden from a signed-in user who cannot edit' do
        sign_in User.new(email: 'viewer@example.com', nuid: '000000005', role: 'standard', groups: [])
        get :show, params: { id: community.id }
        expect(response.body).not_to include(%(href="#{edit_community_path(community.id)}"))
      end

      it 'is shown to a user who can edit' do
        AtlasRb::Community.metadata(community.id,
                                    { 'permissions' => { 'read' => ['public'], 'edit' => ['editors'] } },
                                    nuid: '000000004')
        sign_in User.new(email: 'ed@example.com', nuid: '000000002', groups: ['editors'])
        get :show, params: { id: community.id }
        expect(response.body).to include(%(href="#{edit_community_path(community.id)}"))
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
    # #new now requires authentication (audit G3, deny-by-default macro).
    let(:user) { User.new(email: 'dep@example.com', nuid: '000000004', role: 'standard', groups: []) }

    before { sign_in user }

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

    it 'calls AtlasRb::Community.tombstone and reports success on a 2xx' do
      allow(AtlasRb::Community).to receive(:tombstone)
        .and_return(instance_double(Faraday::Response, success?: true))
      post :tombstone, params: { id: community.id }
      expect(AtlasRb::Community).to have_received(:tombstone).with(community.id)
      expect(subject).to redirect_to(root_path)
      expect(flash[:notice]).to eq('Community deleted.')
    end

    it 'reports a 422 live-members refusal without claiming success' do
      allow(AtlasRb::Community).to receive(:tombstone)
        .and_return(instance_double(Faraday::Response, success?: false, status: 422))
      request.env['HTTP_REFERER'] = community_path(community.id)
      post :tombstone, params: { id: community.id }
      expect(flash[:notice]).to be_nil
      expect(flash[:alert]).to match(/live members/)
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

  # The v1-faithful hide-if-empty gate. Excluding empties at query time (vs a
  # Ruby post-filter) keeps the Type facet counts matching what's shown.
  describe '#empty_showcase_uuids (private)' do
    it 'returns the community featured showcases that have no members' do
      allow(controller).to receive(:featured_showcase_uuids).with('comm-uuid').and_return(%w[a b c])
      allow(controller).to receive(:populated_showcase_ids).with(%w[a b c]).and_return(Set['a'])

      expect(controller.send(:empty_showcase_uuids, 'comm-uuid')).to match_array(%w[b c])
    end

    it 'returns [] when the community has no featured showcases' do
      allow(controller).to receive(:featured_showcase_uuids).and_return([])
      expect(controller.send(:empty_showcase_uuids, 'comm-uuid')).to eq([])
    end
  end

  describe 'show hides empty featured showcases (integration)' do
    render_views

    it 'excludes an empty featured showcase from the browse and its facets' do
      AtlasRb::Community.metadata(community.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
      showcase = AtlasRb::Collection.create(community.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml',
                                            featured: true, nuid: '000000004')
      AtlasRb::Collection.metadata(showcase.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')

      get :show, params: { id: community.id }

      # The empty showcase is filtered at query time, so it's absent from the
      # documents (and therefore from Solr's facet counts).
      expect(assigns(:response).documents.map(&:id)).not_to include(showcase.valkyrie_id)
    ensure
      AtlasRb::Collection.tombstone(showcase.id) if showcase
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
