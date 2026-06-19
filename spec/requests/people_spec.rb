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
    it 'renders a community-scoped browse with the community in the breadcrumb' do
      allow(AtlasRb::Community).to receive(:find).and_return(OpenStruct.new(title: 'Communications'))

      get '/communities/jm640df/people'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Faculty')
      expect(response.body).to include('Communications')
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

    it '404s a NOID with no curated Person record' do
      allow(AtlasRb::Person).to receive(:find).and_raise(JSON::ParserError.new('unexpected end of input'))

      get '/people/nope9999'

      expect(response).to have_http_status(:not_found)
    end
  end
end
