# frozen_string_literal: true

require 'rails_helper'

# Request specs rather than controller specs: the affordance is edit-gated and
# controller specs don't load Warden.
#
# Atlas is stubbed rather than seeded. The concern only reads a title and writes
# a StaffRequest, so standing up real containers would cost two resources per
# example in the shared test store to prove nothing extra.
RSpec.describe 'Container restriction requests', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:nuid) { '000000002' }
  let(:user) do
    User.new(email: 'jane@example.com', password: 'password', nuid: nuid, name: 'Doe, Jane',
             role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end

  # Grants :edit through the staff group the acting user carries.
  let(:acl) do
    AtlasRb::Mash.new('read' => ['public'], 'edit' => [Permissions::STAFF_EDIT_GROUP],
                      'edit_users' => [], 'embargo' => nil)
  end

  before do
    sign_in user
    allow(AtlasRb::Resource).to receive(:permissions).and_return(acl)
    allow(AtlasRb::Collection).to receive(:find).and_return(AtlasRb::Mash.new('id' => 'c1', 'title' => 'Reading Room'))
    allow(AtlasRb::Community).to receive(:find).and_return(AtlasRb::Mash.new('id' => 'm1', 'title' => 'Archives'))
  end

  describe 'POST /collections/:id/request_restriction' do
    it 'opens a restrict request on the ledger and says who asked for what' do
      expect do
        post request_restriction_collection_path('c1'), params: { request_note: 'Archives staff only' }
      end.to change(StaffRequest, :count).by(1)

      request = StaffRequest.last
      expect(request.kind).to eq('restrict')
      expect(request.subject_type).to eq('Collection')
      expect(request.subject_noid).to eq('c1')
      expect(request.subject_title).to eq('Reading Room')
      expect(request.requester_nuid).to eq(nuid)
      expect(request.note).to eq('Archives staff only')
    end

    # Only the :admin role may cascade, and the requester here IS staff, so a
    # request the staff group could work would be a loop. The ledger marks the
    # kind admin-only instead of addressing anybody.
    it 'marks the row admin-only, and sends no inbox message' do
      expect do
        post request_restriction_collection_path('c1'), params: { request_note: 'Archives staff only' }
      end.not_to change(Message, :count)

      expect(StaffRequest.last).to be_admin_only
    end

    it 'refuses an empty note rather than opening a blank request' do
      expect do
        post request_restriction_collection_path('c1'), params: { request_note: '  ' }
      end.not_to change(StaffRequest, :count)

      expect(flash[:alert]).to include('Say who this should still be able to see')
    end
  end

  describe 'POST /communities/:id/request_restriction' do
    it 'names the community, not a collection' do
      post request_restriction_community_path('m1'), params: { request_note: 'nobody' }

      expect(StaffRequest.last.subject_type).to eq('Community')
      expect(StaffRequest.last.subject_title).to eq('Archives')
    end

    # A community restriction cannot be fulfilled in one action — no cascade
    # exists for one — so the row has to carry the route or whoever works it is
    # as stuck as the requester.
    it 'carries the remedy that tells the administrator how to carry it out' do
      post request_restriction_community_path('m1'), params: { request_note: 'nobody' }

      expect(StaffRequest.last.remedy_note).to include('Restrict each collection within it first')
    end

    it 'carries no remedy for a collection, which cascades on its own' do
      post request_restriction_collection_path('c1'), params: { request_note: 'nobody' }

      expect(StaffRequest.last.remedy_note).to be_nil
    end
  end
end
