# frozen_string_literal: true

require 'rails_helper'

# People are public, read-only, NOID-addressed Blacklight content. The index is a
# gated Blacklight search over Person docs (global at /people, community-scoped at
# /communities/:id/people); the profile show fetches the curated Person via AtlasRb
# (mocked here) over a depositor_ssi works search. Index render is smoke-tested
# (the search runs against test Solr, which may hold no Person docs); the live
# "search returns a clickable Person" path is verified in the browser. Load-bearing
# assertions: surfaces render, an unknown NOID 404s, and **no NUID is ever surfaced**.
RSpec.describe 'People', type: :request do
  let(:person) do
    { 'id' => 'pp11aa22', 'nuid' => '000000777', 'display_name' => 'Stephen Flynn',
      'bio' => 'Founding Director of the Global Resilience Institute.',
      'orcid' => '0000-0002-1825-0097' }
  end

  describe 'GET /people (index)' do
    it 'renders the People browse (Blacklight search over Person docs)' do
      get '/people'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('People')
    end

    it 'scopes to People as an applied Type facet so the constraint chip renders' do
      get '/people'

      # The scope rides f[type_ssim]=Person, so the constraints region renders
      # the "Type › Person" chip — parity with the genre landings.
      expect(response.body).to include('search-results-header__constraints')
      expect(response.body).to include('Person')
    end
  end

  describe 'GET /communities/:community_id/people (Faculty & Staff)' do
    it 'trails the breadcrumb through the community and its ancestors' do
      allow(AtlasRb::Community).to receive(:find).and_return(OpenStruct.new(title: 'Communications'))
      # #breadcrumbs walks the community's ancestors off a single find.
      community = OpenStruct.new(
        klass:    'Community',
        resource: OpenStruct.new(
          id: 'jm640df', title: 'Communications',
          ancestors: [{ 'noid' => '9zw3s1h', 'klass' => 'Community', 'title' => 'Northeastern University' }]
        )
      )
      allow(AtlasRb::Resource).to receive(:find).with('jm640df').and_return(community)

      get '/communities/jm640df/people'

      expect(response).to have_http_status(:ok)
      # Northeastern University / Communications / Faculty & Staff
      expect(response.body).to include('Northeastern University')
      expect(response.body).to include('Communications')
      expect(response.body).to include('Faculty')
      # Both ancestors are links: the parent community's path is a *prefix* of the
      # current URL, so it must use :exact matching to stay a link rather than be
      # mis-marked as the current crumb.
      expect(response.body).to include(%(href="#{community_path('9zw3s1h')}"))
      expect(response.body).to include(%(href="#{community_path('jm640df')}"))
    end

    it 'falls back to the lone Faculty & Staff crumb when the community read fails' do
      allow(AtlasRb::Community).to receive(:find).and_return(OpenStruct.new(title: 'Communications'))
      allow(AtlasRb::Resource).to receive(:find).with('jm640df').and_return(nil)

      get '/communities/jm640df/people'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Faculty')
    end
  end

  describe 'GET /people/:id (show)' do
    it 'renders the curated profile header without exposing the NUID' do
      allow(AtlasRb::Person).to receive(:find).and_return(person)

      get '/people/pp11aa22'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Stephen Flynn')
      expect(response.body).to include('Founding Director of the Global Resilience Institute.')
      expect(response.body).to include('0000-0002-1825-0097') # ORCID is fine to show
      expect(response.body).not_to include('000000777') # the NUID is not
    end

    it 'trails the breadcrumb through the affiliated community and its ancestors' do
      affiliated = person.merge('affiliated_community_ids' => ['jm640df'])
      allow(AtlasRb::Person).to receive(:find).and_return(affiliated)
      # #breadcrumbs walks the community's ancestors off a single find.
      community = OpenStruct.new(
        klass:    'Community',
        resource: OpenStruct.new(
          id: 'jm640df', title: 'Communications',
          ancestors: [{ 'noid' => '9zw3s1h', 'klass' => 'Community', 'title' => 'Northeastern University' }]
        )
      )
      allow(AtlasRb::Resource).to receive(:find).with('jm640df').and_return(community)

      get '/people/pp11aa22'

      expect(response).to have_http_status(:ok)
      # Northeastern University / Communications / Faculty & Staff / <name>
      expect(response.body).to include('Northeastern University')
      expect(response.body).to include('Communications')
      expect(response.body).to include('Faculty &amp; Staff')
      expect(response.body).to include(community_path('jm640df'))
      expect(response.body).to include(community_people_path('jm640df'))
    end

    it 'falls back to the flat People trail when the person has no affiliation' do
      allow(AtlasRb::Person).to receive(:find).and_return(person) # no affiliated_community_ids

      get '/people/pp11aa22'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Stephen Flynn')
      expect(response.body).to include(people_path)
    end

    it 'keeps a profile readable when its affiliated community refuses the read' do
      affiliated = person.merge('affiliated_community_ids' => ['gated11'])
      allow(AtlasRb::Person).to receive(:find).and_return(affiliated)
      allow(AtlasRb::Resource).to receive(:find).with('gated11')
                                                .and_raise(AtlasRb::ResourceError.new('GET /resources/gated11 → 403', response: nil))

      get '/people/pp11aa22'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Stephen Flynn')
      expect(response.body).not_to include(community_path('gated11'))
    end

    # A 404 reads as nil, and the breadcrumb walk called `.resource` on it.
    it 'keeps a profile readable when its affiliated community no longer exists' do
      affiliated = person.merge('affiliated_community_ids' => ['gone1234'])
      allow(AtlasRb::Person).to receive(:find).and_return(affiliated)
      allow(AtlasRb::Resource).to receive(:find).with('gone1234').and_return(nil)

      get '/people/pp11aa22'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Stephen Flynn', people_path)
      expect(response.body).not_to include(community_path('gone1234'))
    end

    context 'with a personal workspace' do
      include Devise::Test::IntegrationHelpers

      let(:owner) { person.merge('personal_root_id' => 'root1234') }
      let(:staff_user) do
        User.new(email: 'staff@example.com', password: 'password', nuid: '000000002', role: 'privileged',
                 groups: ['northeastern:drs:repository:staff'])
      end
      let(:guest_user) do
        User.new(email: 'guest@example.com', password: 'password', nuid: '000000001', role: 'guest', groups: [])
      end

      before do
        allow(AtlasRb::User).to receive(:resolve).and_return([])
        allow(AtlasRb::Person).to receive(:find).and_return(owner)
        allow(AtlasRb::Resource).to receive(:permissions).with('root1234').and_return(
          AtlasRb::Mash.new('read' => ['public'], 'edit' => ['northeastern:drs:repository:staff'])
        )
      end

      it "offers an editor the Add menu into the person's workspace" do
        sign_in staff_user

        get '/people/pp11aa22'

        expect(response.body).to include(new_collection_work_path('root1234'))
        expect(response.body).to include(new_collection_collection_path('root1234'))
      end

      it 'offers no Add menu to a user who cannot edit the workspace' do
        sign_in guest_user

        get '/people/pp11aa22'

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('breadcrumb-add')
      end

      it 'offers no Add menu when signed out, and does not read the workspace' do
        get '/people/pp11aa22'

        expect(response.body).not_to include('breadcrumb-add')
        expect(AtlasRb::Resource).not_to have_received(:permissions)
      end
    end

    it '404s a NOID with no curated Person record' do
      allow(AtlasRb::Person).to receive(:find).and_return(nil) # atlas_rb returns nil for a 404

      get '/people/nope9999'

      expect(response).to have_http_status(:not_found)
    end
  end
end
