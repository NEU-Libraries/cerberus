# frozen_string_literal: true

require 'rails_helper'

# A community's people in the admin hub. atlas_rb and the Solr list are
# stubbed; the affiliation contract is Atlas's and covered there.
RSpec.describe 'Admin::CommunityPeople', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) { User.new(email: 'admin@example.com', nuid: '000000004', name: 'User, Admin', role: 'admin') }
  # The delegated tier: Atlas does not grant it Person :update.
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: [Permissions::STAFF_EDIT_GROUP, Permissions::ADMIN_GROUP])
  end
  let(:person) do
    SolrDocument.new('id' => 'u1', 'noid_ssi' => 'pers123', 'display_name_ssi' => 'Mickey Gasper',
                     'nuid_ssi' => '000000014')
  end

  before do
    allow(AtlasRb::Community).to receive(:find).with('comm456').and_return(OpenStruct.new(title: 'School of Law'))
    allow(CommunityAffiliates).to receive(:call).and_return(CommunityAffiliates::Result.new([person], 1))
  end

  describe 'as an admin' do
    before { sign_in admin_user }

    it "lists the community's people, each removable" do
      get admin_community_people_path('comm456')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('School of Law', 'Mickey Gasper', '000000014', '1 person',
                                       admin_community_person_path('comm456', 'pers123'))
    end

    it 'offers Add only for someone not already in the community' do
      allow(AtlasRb::Person).to receive(:list).with(hash_including(q: 'gas'))
                                              .and_return([{ 'id' => 'pers123', 'display_name' => 'Mickey Gasper' },
                                                           { 'id' => 'pers999', 'display_name' => 'Gas Lamp' }])

      get admin_community_people_path('comm456', q: 'gas')

      expect(response.body).to include('Already in this community', 'Gas Lamp')
      expect(response.body.scan('name="person_id"').size).to eq(1)
    end

    it 'adds the person and returns to the page' do
      expect(AtlasRb::Person).to receive(:add_affiliation).with('pers999', 'comm456', nuid: anything)

      post admin_community_people_path('comm456'), params: { person_id: 'pers999' }

      expect(response).to redirect_to(admin_community_people_path('comm456'))
      expect(flash[:notice]).to eq('Person added to this community.')
    end

    it 'removes the person and returns to the page' do
      expect(AtlasRb::Person).to receive(:remove_affiliation).with('pers123', 'comm456', nuid: anything)

      delete admin_community_person_path('comm456', 'pers123')

      expect(response).to redirect_to(admin_community_people_path('comm456'))
      expect(flash[:notice]).to eq('Person removed from this community.')
    end

    it 'says nothing changed when Atlas refuses' do
      allow(AtlasRb::Person).to receive(:add_affiliation).and_raise(Faraday::ConnectionFailed, 'down')

      post admin_community_people_path('comm456'), params: { person_id: 'pers999' }

      expect(flash[:alert]).to eq("Couldn't add that person. Nothing was changed.")
    end

    it 'is not found for an unknown community' do
      allow(AtlasRb::Community).to receive(:find).with('nope123').and_return(nil)

      get admin_community_people_path('nope123')

      expect(response).to have_http_status(:not_found)
    end
  end

  it 'refuses a delegated admin, whom Atlas would refuse' do
    sign_in delegate_user
    expect(AtlasRb::Person).not_to receive(:add_affiliation)

    post admin_community_people_path('comm456'), params: { person_id: 'pers123' }

    expect(response).to have_http_status(:forbidden)
  end
end
