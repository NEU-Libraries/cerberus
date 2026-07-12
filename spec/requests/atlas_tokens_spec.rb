# frozen_string_literal: true

require 'rails_helper'

# The My DRS "Programmatic access" surface: minting / regenerating / revoking a
# personal-access JWT (ATLAS_JWT). The atlas_rb System::Token binding is stubbed
# — these specs cover Cerberus's group gate, the reveal-once render, and the
# regenerate = revoke-then-mint ordering, not the Atlas round-trip.
RSpec.describe 'Atlas tokens', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:api_group) { Permissions::API_GROUP }

  let(:member) do
    User.new(email: 'api@example.com', password: 'password',
             nuid: '000000002', role: 'privileged', groups: [api_group])
  end

  let(:non_member) do
    User.new(email: 'plain@example.com', password: 'password',
             nuid: '000000004', role: 'standard', groups: [])
  end

  # My DRS renders now consult the accounts list; keep these token specs off the
  # live call by defaulting to a single account (so no switcher panel appears).
  before do
    allow(AtlasRb::User).to receive(:accounts).and_return(
      AtlasRb::Mash.new('nuid' => nil, 'accounts' => [])
    )
  end

  describe 'authorization' do
    it 'forbids an anonymous visitor from minting' do
      post '/atlas_token'
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids a signed-in non-member from minting' do
      sign_in non_member
      post '/atlas_token'
      expect(response).to have_http_status(:forbidden)
    end

    it 'hides the section from a non-member on the My DRS page' do
      sign_in non_member
      allow(AtlasRb::Person).to receive(:resolve).and_return([])

      get '/my_drs'

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Programmatic access')
    end
  end

  context 'as an API-group member' do
    before { sign_in member }

    it 'shows the section (generate state) on the My DRS page' do
      allow(AtlasRb::Person).to receive(:resolve).and_return([])

      get '/my_drs'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Programmatic access')
      expect(response.body).to include('Generate token')
    end

    it 'mints a token and reveals it once' do
      allow(AtlasRb::System::Token).to receive(:mint).with(nuid: '000000002').and_return('jwt.abc.123')

      post '/atlas_token'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('jwt.abc.123')
      expect(response.body).to include("won't be shown again")
    end

    it 'regenerate revokes outstanding tokens before minting' do
      allow(AtlasRb::System::Token).to receive(:mint).with(nuid: '000000002').and_return('jwt.new.999')

      expect(AtlasRb::System::Token).to receive(:revoke).with(nuid: '000000002').ordered
      expect(AtlasRb::System::Token).to receive(:mint).with(nuid: '000000002').ordered.and_return('jwt.new.999')

      post '/atlas_token', params: { regenerate: true }

      expect(response.body).to include('jwt.new.999')
    end

    it 'surfaces a clean message when Atlas has no user row (mint returns nil)' do
      allow(AtlasRb::System::Token).to receive(:mint).and_return(nil)

      post '/atlas_token'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('mint a token for your account') # apostrophe HTML-escaped in dynamic output
      expect(response.body).to include('Generate token') # back to the un-revealed state
    end

    it 'revokes all outstanding tokens' do
      expect(AtlasRb::System::Token).to receive(:revoke).with(nuid: '000000002').and_return(true)

      delete '/atlas_token'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('All personal-access tokens revoked.')
    end
  end
end
