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

    context 'analytics tab' do
      let(:admin_user) do
        User.new(email: 'admin@example.com', nuid: '000000004', groups: [], role: 'admin')
      end

      it 'renders the Analytics tab, scoped to this collection, for any editor with edit rights' do
        get :edit, params: { id: collection.id }
        expect(response.body).to match(/<button[^>]*id="analytics-tab"/)
        expect(response.body).to include('Views', 'Downloads', 'Unique visitors')
      end

      it 'does not show the "Open in Usage Analytics" drill-down link to a non-admin editor (it leads to an admin-only page)' do
        get :edit, params: { id: collection.id }
        expect(response.body).not_to include('Open in Usage Analytics')
      end

      it 'shows the "Open in Usage Analytics" drill-down link to an admin' do
        sign_in admin_user
        get :edit, params: { id: collection.id }
        expect(response.body).to include('Open in Usage Analytics')
      end
    end

    context 'analytics tab item lookup, facet, and composition' do
      let!(:sub_collection) do
        publicize_ancestry!(community: community, collection: collection)
        c = AtlasRb::Collection.create(collection.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml', nuid: '000000004')
        AtlasRb::Collection.metadata(c.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
        c
      end
      let!(:other_community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', nuid: '000000004') }
      # Same MODS fixture (and thus identical title) as sub_collection, but
      # homed under an entirely different Community — the containment check
      # must exclude it on subtree membership, not title.
      let!(:foreign_collection) do
        publicize_ancestry!(community: other_community)
        c = AtlasRb::Collection.create(other_community.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml', nuid: '000000004')
        AtlasRb::Collection.metadata(c.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
        c
      end

      it 'finds an in-subtree sub-collection via item lookup but not a same-titled resource outside the subtree' do
        get :edit, params: { id: collection.id, q: sub_collection.title }

        expect(response.body).to include(sub_collection.id, 'Scope')
        expect(response.body).not_to include(foreign_collection.id)
      end

      # Every URL this tab emits must carry the #analytics fragment, or the
      # round trip drops the viewer back on the default (Metadata) tab.
      it 'anchors the item-lookup form and result links back to the Analytics tab' do
        get :edit, params: { id: collection.id, q: sub_collection.title }

        expect(response.body).to match(%r{<form[^>]*action="[^"]*/edit#analytics"})
        expect(response.body).to match(/href="[^"]*analytics_item_noid=[^"]*#analytics"/)
        expect(response.body).not_to include('anchor=analytics')
      end

      it 'honors an in-subtree drill-down and shows the "Scoped to" chip' do
        get :edit, params: { id: collection.id, analytics_item_noid: sub_collection.id,
                             analytics_item_uuid: sub_collection.valkyrie_id, analytics_item_klass: 'Collection',
                             analytics_item_title: sub_collection.title }

        expect(response.body).to include("Scoped to: Collection: #{sub_collection.title}")
      end

      it 'ignores a hand-crafted drill-down param pointing outside the subtree (the containment boundary)' do
        get :edit, params: { id: collection.id, analytics_item_noid: foreign_collection.id,
                             analytics_item_uuid: foreign_collection.valkyrie_id, analytics_item_klass: 'Collection',
                             analytics_item_title: foreign_collection.title }

        expect(response.body).not_to include('Scoped to:')
      end

      it 'facets by content type and shows the "Faceted by" chip' do
        get :edit, params: { id: collection.id, analytics_facet_type: 'content', analytics_facet_value: 'Image' }

        expect(response.body).to include('Faceted by: Content: Image')
      end

      it 'clears a drill-down back to the base collection scope, not fully unscoped' do
        get :edit, params: { id: collection.id, analytics_item_noid: sub_collection.id,
                             analytics_item_uuid: sub_collection.valkyrie_id, analytics_item_klass: 'Collection',
                             analytics_item_title: sub_collection.title }
        clear_href = response.body[/<a[^>]*aria-label="Clear item scope"[^>]*href="([^"]*)"/, 1]

        expect(clear_href).to be_present
        expect(clear_href).not_to include('analytics_item_noid')
        expect(clear_href).to end_with('#analytics')
      end

      it 'renders the Composition tab scoped to this collection\'s own subtree' do
        get :edit, params: { id: collection.id }

        expect(response.body).to include('Composition', 'Faculty', 'Staff', 'Public works', 'Private works')
      end
    end
  end

  describe 'show' do
    render_views

    before do
      publicize_ancestry!(community: community)
      AtlasRb::Collection.metadata(collection.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
    end

    it 'renders the show partial' do
      get :show, params: { id: collection.id }
      expect(response).to render_template('collections/show')
      expect(CGI.unescapeHTML(response.body)).to include(collection.title)
    end

    context 'Edit affordance is gated on the :edit ability' do
      it 'is hidden from a signed-in user who cannot edit' do
        sign_in User.new(email: 'viewer@example.com', nuid: '000000005', role: 'standard', groups: [])
        get :show, params: { id: collection.id }
        expect(response.body).not_to include(%(href="#{edit_collection_path(collection.id)}"))
      end

      it 'is shown to a user who can edit' do
        AtlasRb::Collection.metadata(collection.id,
                                     { 'permissions' => { 'read' => ['public'], 'edit' => ['editors'] } },
                                     nuid: '000000004')
        sign_in User.new(email: 'ed@example.com', nuid: '000000002', groups: ['editors'])
        get :show, params: { id: collection.id }
        expect(response.body).to include(%(href="#{edit_collection_path(collection.id)}"))
      end
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
      # The Work is two tiers down, so every container above it has to be public
      # before it can be — the enclosing `before` widens community + collection,
      # and sub_collection widens itself above.
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
    # #new now requires authentication (audit G3, deny-by-default macro).
    let(:user) { User.new(email: 'dep@example.com', nuid: '000000004', role: 'standard', groups: []) }

    before { sign_in user }

    it 'assigns a open struct to collection' do
      get :new, params: { community_id: community.id }
      expect(assigns(:collection)).to be_a(OpenStruct)
    end

    it 'renders the new partial' do
      get :new, params: { community_id: community.id }
      expect(response).to render_template('collections/new')
    end

    # A Collection hangs from either container type, so the form has to post
    # back to whichever segment carried the parent.
    it 'targets the nested create path for the destination it was opened from' do
      get :new, params: { collection_id: collection.id }
      expect(assigns(:create_path)).to eq(collection_collections_path(collection.id))
    end

    # The create form carries the same two controls the Permissions tab does, so
    # a Collection is born with a chosen audience rather than a silent one.
    context 'permissions section' do
      render_views

      it 'renders the group grant editor' do
        get :new, params: { community_id: community.id }

        expect(response.body).to include('Group Permissions')
        expect(response.body).to include('collection[permissions][new][group_id]')
      end

      # Atlas copies the destination's read ACL onto a new child, so the form has
      # to open holding it. Showing a blank slate would invite a curator to
      # submit one and silently drop grants they never saw.
      it 'prefills the grants the new collection would inherit' do
        AtlasRb::Community.metadata(community.id,
                                    { 'permissions' => { 'read' => ['editors'] } }, nuid: '000000004')

        get :new, params: { community_id: community.id }

        expect(assigns(:permissions).map(&:group_id)).to include('editors')
        expect(response.body).to include('collection[permissions][1][group_id]')
      end

      # A brand-new Collection has nothing inside it, so the cascade warning the
      # edit tab carries must not appear — and leaving @narrowing_allowed unset
      # is what keeps _visibility_control off its locked branch.
      it 'leaves the narrowing state unset' do
        get :new, params: { community_id: community.id }

        expect(assigns(:narrowing_allowed)).to be_nil
        expect(response.body).not_to include('narrowing-confirm')
      end

      it 'withholds Public under a private destination and names it' do
        get :new, params: { community_id: community.id }

        control = response.parsed_body.at_css('[name="mass"]')
        expect(assigns(:public_allowed)).to be(false)
        expect(control.name).to eq('input')
        expect(control['value']).to eq('private')
        expect(CGI.unescapeHTML(response.body)).to include("#{community.title}” is private")
      end

      # Public is what the Collection would inherit, so preselecting it is what
      # lets the control add a choice without moving the outcome for a reader
      # who ignores it. Preselecting Private would narrow every child of a
      # public container instead.
      it 'offers the choice under a public destination and preselects the inherited Public' do
        publicize_ancestry!(community: community)

        get :new, params: { community_id: community.id }

        control = response.parsed_body.at_css('[name="mass"]')
        expect(assigns(:public_allowed)).to be(true)
        expect(assigns(:public)).to be(true)
        expect(control.name).to eq('select')
        expect(control.at_css('option[selected]')['value']).to eq('public')
      end
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

    it 'calls AtlasRb::Collection.tombstone and reports success on a 2xx' do
      allow(AtlasRb::Collection).to receive(:tombstone)
        .and_return(instance_double(Faraday::Response, success?: true))
      post :tombstone, params: { id: collection.id }
      expect(AtlasRb::Collection).to have_received(:tombstone).with(collection.id)
      expect(subject).to redirect_to(root_path)
      expect(flash[:notice]).to eq('Collection deleted.')
    end

    it 'reports a 422 live-members refusal without claiming success' do
      allow(AtlasRb::Collection).to receive(:tombstone)
        .and_return(instance_double(Faraday::Response, success?: false, status: 422))
      request.env['HTTP_REFERER'] = collection_path(collection.id)
      post :tombstone, params: { id: collection.id }
      expect(flash[:notice]).to be_nil
      expect(flash[:alert]).to match(/live members/)
    end
  end

  describe 'create' do
    let(:user) { User.new(email: 'creator@example.com', nuid: '000000004', groups: ['editors']) }

    before { sign_in user }

    it 'seeds the new collection title + description via the structure-safe MODS merge (not plain_title=)' do
      post :create, params: { community_id: community.id,
                              collection:   { title: 'BrandNewCollection', description: 'CollectionAbstract' } }

      created_id = response.location.split('/').last
      created = AtlasRb::Collection.find(created_id)
      expect(created.title).to eq('BrandNewCollection')
      expect(created.description).to include('CollectionAbstract')
    ensure
      AtlasRb::Collection.tombstone(created_id) if created_id
    end

    it 'rejects a blank title without minting a collection' do
      allow(AtlasRb::Collection).to receive(:create)

      post :create, params: { community_id: community.id, collection: { title: '', description: 'Y' } }

      expect(AtlasRb::Collection).not_to have_received(:create)
      expect(flash[:alert]).to eq('Please provide a title.')
      expect(response).to redirect_to(new_community_collection_path(community.id))
    end

    # Atlas copies the destination's ACL onto a new child, and the form opens
    # holding that copy — so submitting it untouched has to land where a bare
    # create would. Otherwise adding the control would itself change what
    # creating a Collection does.
    it 'lands on the inherited ACL when the prefilled controls are submitted untouched' do
      publicize_ancestry!(community: community)
      reference = AtlasRb::Collection.create(community.id, nuid: '000000004')
      inherited = Array(AtlasRb::Resource.permissions(reference.id)&.read)

      post :create, params: { community_id: community.id, mass: 'public',
                              collection: { title: 'InheritedCollection', description: 'D' } }

      created_id = response.location.split('/').last
      expect(Array(AtlasRb::Resource.permissions(created_id)&.read)).to match_array(inherited)
    ensure
      [reference&.id, created_id].compact.each { |id| AtlasRb::Collection.tombstone(id) }
    end

    it 'applies the submitted visibility and group grants to the new collection' do
      publicize_ancestry!(community: community)

      post :create, params: { community_id: community.id, mass: 'public',
                              collection: { title: 'PermissionedCollection', description: 'D',
                                            permissions: { '1' => { group_id: 'editors', ability: 'read' } } } }

      created_id = response.location.split('/').last
      expect(Array(AtlasRb::Resource.permissions(created_id)&.read)).to contain_exactly('public', 'editors')
    ensure
      AtlasRb::Collection.tombstone(created_id) if created_id
    end

    # Atlas assigns edit_groups, edit_users and embargo unconditionally from the
    # payload, so the submitted grants have to be merged into the envelope the
    # new Collection was minted with. Replacing it would strip the edit grants
    # Atlas just gave it — a form naming only read groups names no edit ones.
    it 'merges the submitted grants into the minted envelope rather than replacing it' do
      allow(AtlasRb::Collection).to receive(:metadata).and_call_original

      post :create, params: { community_id: community.id, mass: 'private',
                              collection: { title: 'EnvelopeCollection', description: 'D',
                                            permissions: { '1' => { group_id: 'editors', ability: 'read' } } } }

      created_id = response.location.split('/').last
      expect(AtlasRb::Collection).to have_received(:metadata).with(
        created_id, hash_including(permissions: hash_including(edit: [Permissions::STAFF_EDIT_GROUP],
                                                               read: ['editors']))
      )
    ensure
      AtlasRb::Collection.tombstone(created_id) if created_id
    end

    # #apply_permissions would address params[:id] — nil on this path — and
    # compare against the DESTINATION's envelope, which is what @permissions
    # still holds here. A Collection one line old has nothing to cascade to.
    it 'does not consult the narrowing cascade for a collection it has just created' do
      allow(NarrowingRequest).to receive(:call)

      post :create, params: { community_id: community.id, mass: 'private',
                              collection: { title: 'NoCascadeCollection', description: 'D' } }

      created_id = response.location.split('/').last
      expect(NarrowingRequest).not_to have_received(:call)
    ensure
      AtlasRb::Collection.tombstone(created_id) if created_id
    end

    # The destination is a route segment, so there is no request shape that
    # reaches create without one. (GET /collections still routes — that's the
    # index; only the unparented POST is gone.)
    it 'has no unparented create route' do
      expect { Rails.application.routes.recognize_path('/collections', method: :post) }
        .to raise_error(ActionController::RoutingError)
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
