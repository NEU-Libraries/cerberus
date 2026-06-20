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
      'title' => 'Professor of Political Science',
      'bio' => 'Founding Director of the Global Resilience Institute.',
      'orcid' => '0000-0002-1825-0097' }
  end

  describe 'GET /people (index)' do
    it 'renders the People browse (Blacklight search over Person docs)' do
      get '/people'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('People')
    end
  end

  describe 'GET /communities/:community_id/people (Faculty & Staff)' do
    it 'trails the breadcrumb through the community and its ancestors' do
      allow(AtlasRb::Community).to receive(:find).and_return(OpenStruct.new(title: 'Communications'))
      # #breadcrumbs walks the community's ancestor_chain off a single find.
      community = OpenStruct.new(
        klass:    'Community',
        resource: OpenStruct.new(
          id: 'jm640df', title: 'Communications',
          ancestor_chain: [{ 'noid' => '9zw3s1h', 'klass' => 'Community', 'title' => 'Northeastern University' }]
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
  end

  describe 'GET /people/:id (show)' do
    it 'renders the curated profile header without exposing the NUID' do
      allow(AtlasRb::Person).to receive(:find).and_return(person)

      get '/people/pp11aa22'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Stephen Flynn')
      expect(response.body).to include('Professor of Political Science')
      expect(response.body).to include('0000-0002-1825-0097') # ORCID is fine to show
      expect(response.body).not_to include('000000777') # the NUID is not
    end

    it 'trails the breadcrumb through the affiliated community and its ancestors' do
      affiliated = person.merge('affiliated_community_ids' => ['jm640df'])
      allow(AtlasRb::Person).to receive(:find).and_return(affiliated)
      # #breadcrumbs walks the community's ancestor_chain off a single find.
      community = OpenStruct.new(
        klass:    'Community',
        resource: OpenStruct.new(
          id: 'jm640df', title: 'Communications',
          ancestor_chain: [{ 'noid' => '9zw3s1h', 'klass' => 'Community', 'title' => 'Northeastern University' }]
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

    it '404s a NOID with no curated Person record' do
      allow(AtlasRb::Person).to receive(:find).and_raise(JSON::ParserError.new('unexpected end of input'))

      get '/people/nope9999'

      expect(response).to have_http_status(:not_found)
    end
  end
end
