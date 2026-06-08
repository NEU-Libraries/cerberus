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

    it 'renders breadcrumbs (in the container header)' do
      get :edit, params: { id: community.id }
      expect(response.body).to include('aria-label="breadcrumb"')
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
end
