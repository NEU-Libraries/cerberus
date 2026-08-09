# frozen_string_literal: true

require 'rails_helper'

# Request specs rather than controller specs: the affordance is edit-gated and
# controller specs don't load Warden.
#
# Atlas is stubbed rather than seeded. The concern only reads a title and writes
# an AdminNotice, so standing up real containers would cost two resources per
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
    it 'records a restrict request and says who asked for what' do
      expect do
        post request_restriction_collection_path('c1'), params: { request_note: 'Archives staff only' }
      end.to change(AdminNotice, :count).by(1)

      notice = AdminNotice.last
      expect(notice.kind).to eq('request_restrict')
      expect(notice).to be_request
      expect(notice.subject_noid).to eq('c1')
      expect(notice.actor_nuid).to eq(nuid)
      expect(notice.detail(:subject_type)).to eq('Collection')
      expect(notice.detail(:subject_title)).to eq('Reading Room')
      expect(notice.detail(:note)).to eq('Archives staff only')
    end

    # Nothing is addressed to anybody. Staff read the ledger; the requester
    # hears back off-site.
    it 'sends no inbox message' do
      expect do
        post request_restriction_collection_path('c1'), params: { request_note: 'Archives staff only' }
      end.not_to change(Message, :count)
    end

    it 'refuses an empty note rather than recording a blank request' do
      expect do
        post request_restriction_collection_path('c1'), params: { request_note: '  ' }
      end.not_to change(AdminNotice, :count)

      expect(flash[:alert]).to include('Say who this should still be able to see')
    end
  end

  describe 'POST /communities/:id/request_restriction' do
    it 'names the community, not a collection' do
      post request_restriction_community_path('m1'), params: { request_note: 'nobody' }

      expect(AdminNotice.last.detail(:subject_type)).to eq('Community')
      expect(AdminNotice.last.detail(:subject_title)).to eq('Archives')
    end
  end
end
