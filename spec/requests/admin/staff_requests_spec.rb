# frozen_string_literal: true

require 'rails_helper'

# One request on the ledger. The surface carries no remedy of its own — every
# repair it points at is gated where it lives — so what is tested here is the
# shared state and the reply that closes the loop with the requester.
RSpec.describe 'Admin staff requests', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    User.new(email: 'admin@example.com', password: 'password', nuid: '000000004', role: 'admin')
  end
  let(:delegate) do
    User.new(email: 'delegate@example.com', password: 'password', nuid: '000000002', role: 'privileged',
             groups: [Permissions::STAFF_EDIT_GROUP, 'northeastern:drs:repository:admin'])
  end

  let(:withdrawal) do
    StaffRequest.create!(kind: 'withdraw', subject_type: 'Work', subject_noid: 'w1',
                         subject_title: 'thesis.pdf', requester_nuid: '000000010',
                         note: 'No longer authoritative.')
  end
  let(:restriction) do
    StaffRequest.create!(kind: 'restrict', subject_type: 'Community', subject_noid: 'm1',
                         subject_title: 'Archives', requester_nuid: '000000010',
                         note: 'Archives staff only')
  end

  describe 'show' do
    before { sign_in admin }

    it 'shows what was asked, by whom, and points at the remedy' do
      get admin_staff_request_path(withdrawal)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('thesis.pdf')
      expect(response.body).to include('No longer authoritative.')
      expect(response.body).to include('Open the work to withdraw it')
    end

    # Narrowing a community does not cascade, so the fulfiller has to be told
    # the route or the request is unanswerable.
    it 'carries the community remedy on a community restriction' do
      get admin_staff_request_path(restriction)

      expect(response.body).to include('Restrict each collection within it first')
    end

    it '404s an id that does not exist' do
      get admin_staff_request_path(id: 999_999)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'claiming' do
    before { sign_in admin }

    it 'claims and records who has it' do
      post claim_admin_staff_request_path(withdrawal)

      expect(withdrawal.reload).to be_claimed
      expect(withdrawal.claimed_by_nuid).to eq('000000004')
      expect(flash[:notice]).to eq('Claimed.')
    end

    it 'returns a claimed request to the queue' do
      withdrawal.claim!('000000004')

      delete unclaim_admin_staff_request_path(withdrawal)

      expect(withdrawal.reload).to be_open
      expect(withdrawal.claimed_by_nuid).to be_nil
    end
  end

  describe 'resolving' do
    before { sign_in admin }

    it 'resolves and replies to the requester in their inbox' do
      expect do
        post resolve_admin_staff_request_path(withdrawal),
             params: { resolution: 'done', resolution_note: 'Withdrawn this morning.' }
      end.to change(Message, :count).by(1)

      expect(withdrawal.reload).to be_resolved
      expect(withdrawal.resolution).to eq('done')
      expect(withdrawal.resolved_by_nuid).to eq('000000004')

      message = Message.last
      expect(message.recipient_nuid).to eq('000000010')
      expect(message).to be_system
      expect(message.subject).to include('thesis.pdf')
      expect(message.body).to include('Withdrawn this morning.')
    end

    it 'records a decline and says so to the requester' do
      post resolve_admin_staff_request_path(withdrawal),
           params: { resolution: 'declined', resolution_note: 'It is cited elsewhere.' }

      expect(withdrawal.reload.resolution).to eq('declined')
      expect(Message.last.body).to include('did not carry out')
    end

    it 'refuses an unknown resolution rather than closing the request' do
      post resolve_admin_staff_request_path(withdrawal), params: { resolution: 'maybe' }

      expect(withdrawal.reload).to be_open
      expect(flash[:alert]).to include('done or declined')
    end
  end

  # Only :admin may run a visibility cascade, so only :admin can fulfil a
  # restrict. The delegate tier still sees the row — seeing the queue is the
  # point — but the actions are refused on the server, not just hidden.
  describe 'a restriction request and the delegate tier' do
    before { sign_in delegate }

    it 'lets a delegate read it' do
      get admin_staff_request_path(restriction)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('An administrator has to act on this one')
    end

    it 'refuses a delegate claiming it' do
      post claim_admin_staff_request_path(restriction)

      expect(response).to have_http_status(:forbidden)
      expect(restriction.reload).to be_open
    end

    it 'refuses a delegate resolving it' do
      post resolve_admin_staff_request_path(restriction), params: { resolution: 'done' }

      expect(response).to have_http_status(:forbidden)
      expect(restriction.reload).not_to be_resolved
    end

    it 'still lets a delegate work a withdrawal' do
      post claim_admin_staff_request_path(withdrawal)

      expect(withdrawal.reload).to be_claimed
      expect(withdrawal.claimed_by_nuid).to eq('000000002')
    end
  end
end
