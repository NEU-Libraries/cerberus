# frozen_string_literal: true

require 'rails_helper'

# Request specs rather than controller specs: the affordance is edit-gated and
# controller specs don't load Warden.
#
# Atlas is stubbed rather than seeded. The concern only reads a title and writes
# a Message, so standing up real containers would cost two resources per example
# in the shared test store to prove nothing extra.
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
    it 'messages the administrators and says who asked for what' do
      expect do
        post request_restriction_collection_path('c1'), params: { request_note: 'Archives staff only' }
      end.to change(Message, :count).by(1)

      message = Message.last
      expect(message.recipient_group).to eq(Permissions::ADMIN_GROUP)
      expect(message.sender_nuid).to eq(nuid)
      expect(message.subject).to include('Reading Room')
      expect(message.body).to include('Doe, Jane', 'Should still be able to see it: Archives staff only')
    end

    # The point of the affordance is reaching someone who can act. Only the
    # :admin role may cascade, and the requester here IS staff, so addressing
    # the staff group would send it to their own inbox.
    it 'does not address the staff group' do
      post request_restriction_collection_path('c1'), params: { request_note: 'Archives staff only' }

      expect(Message.last.recipient_group).not_to eq(Permissions::STAFF_EDIT_GROUP)
    end

    it 'refuses an empty note rather than sending a blank request' do
      expect do
        post request_restriction_collection_path('c1'), params: { request_note: '  ' }
      end.not_to change(Message, :count)

      expect(flash[:alert]).to include('Say who this should still be able to see')
    end
  end

  describe 'POST /communities/:id/request_restriction' do
    # A community restriction cannot be fulfilled in one action — no cascade
    # exists for one — so the message has to carry the route or its recipient is
    # as stuck as the requester.
    it 'tells the administrator how to actually carry it out' do
      post request_restriction_community_path('m1'), params: { request_note: 'nobody' }

      expect(Message.last.body).to include('Restrict each collection within it first')
    end

    it 'names the community, not a collection' do
      post request_restriction_community_path('m1'), params: { request_note: 'nobody' }

      expect(Message.last.subject).to include('Archives')
      expect(Message.last.body).to include('Community: “Archives”')
    end
  end
end
