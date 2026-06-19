# frozen_string_literal: true

require 'rails_helper'

# The People surfaces are public, read-only, and NOID-addressed. The AtlasRb::Person
# boundary is mocked here (People depend on a freshly-shipped Atlas amendment that
# atlas-test may not yet carry); real end-to-end integration is verified in the
# browser against dev Atlas. The load-bearing assertions are: profiles render from
# the curated Person, an unknown NOID is a clean 404, and **no NUID is ever surfaced**
# (URLs are NOID-keyed; the page never prints the nuid).
RSpec.describe 'People', type: :request do
  let(:person) do
    { 'id' => 'pp11aa22', 'nuid' => '000000777', 'display_name' => 'Stephen Flynn',
      'title' => 'Professor of Political Science',
      'bio' => 'Founding Director of the Global Resilience Institute.',
      'orcid' => '0000-0002-1825-0097' }
  end

  describe 'GET /people (index)' do
    it 'lists curated people by name, links to the NOID-keyed profile, surfaces no NUID' do
      allow(AtlasRb::Person).to receive(:list).and_return([person])

      get '/people'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Stephen Flynn')
      expect(response.body).to include(person_path('pp11aa22'))
      expect(response.body).not_to include('000000777')
    end

    it 'offers a Next link only when the page is full' do
      allow(AtlasRb::Person).to receive(:list).and_return(Array.new(PeopleController::PER_PAGE) { person })

      get '/people'

      expect(response.body).to include(people_path(page: 2))
    end

    it 'renders an empty state when no one has a profile yet' do
      allow(AtlasRb::Person).to receive(:list).and_return([])

      get '/people'

      expect(response.body).to include('No people to show yet')
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
