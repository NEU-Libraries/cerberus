# frozen_string_literal: true

require 'rails_helper'

# The community Edit page's People tab writes. atlas_rb is stubbed; the
# affiliation contract is Atlas's and covered there.
RSpec.describe 'CommunityAffiliations', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) { User.new(email: 'admin@example.com', nuid: '000000004', name: 'User, Admin', role: 'admin') }
  # The delegated tier: Atlas does not grant it Person :update.
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: [Permissions::STAFF_EDIT_GROUP, Permissions::ADMIN_GROUP])
  end

  describe 'as an admin' do
    before { sign_in admin_user }

    it 'adds the person and returns to the People tab' do
      expect(AtlasRb::Person).to receive(:add_affiliation).with('pers123', 'comm456', nuid: anything)

      post affiliations_community_path('comm456'), params: { person_id: 'pers123' }

      expect(response).to redirect_to(edit_community_path('comm456', tab: 'people'))
      expect(flash[:notice]).to eq('Person added to this community.')
    end

    it 'removes the person and returns to the People tab' do
      expect(AtlasRb::Person).to receive(:remove_affiliation).with('pers123', 'comm456', nuid: anything)

      delete affiliation_community_path('comm456', 'pers123')

      expect(response).to redirect_to(edit_community_path('comm456', tab: 'people'))
      expect(flash[:notice]).to eq('Person removed from this community.')
    end

    it 'says nothing changed when Atlas refuses' do
      allow(AtlasRb::Person).to receive(:add_affiliation).and_raise(Faraday::ConnectionFailed, 'down')

      post affiliations_community_path('comm456'), params: { person_id: 'pers123' }

      expect(flash[:alert]).to eq("Couldn't add that person. Nothing was changed.")
    end
  end

  it 'refuses a delegated admin, whom Atlas would refuse' do
    sign_in delegate_user
    expect(AtlasRb::Person).not_to receive(:add_affiliation)

    post affiliations_community_path('comm456'), params: { person_id: 'pers123' }

    expect(response).to have_http_status(:forbidden)
  end

  it 'sends the signed-out to sign in' do
    delete affiliation_community_path('comm456', 'pers123')
    expect(response).to redirect_to(new_user_session_path)
  end
end
