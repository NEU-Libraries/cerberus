# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Messages', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000002', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end
  let(:guest_user) do
    User.new(email: 'guest@example.com', password: 'password',
             nuid: '000000001', role: 'guest', groups: [])
  end

  before { allow(AtlasRb::User).to receive(:resolve).and_return([]) }

  describe 'access gate' do
    it 'redirects anonymous visitors to sign in' do
      get '/inbox'
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'rejects guest sessions with 403 (guests have no inbox)' do
      sign_in guest_user
      get '/inbox'
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /inbox' do
    before { sign_in staff_user }

    let!(:direct) do
      Message.create!(subject: 'Direct hello', recipient_nuid: staff_user.nuid, sender_nuid: '000000004')
    end
    let!(:group_message) do
      Message.create!(subject: 'Staff notice', recipient_group: 'northeastern:drs:repository:staff')
    end
    let!(:someone_elses) { Message.create!(subject: 'Not yours', recipient_nuid: '000000099') }

    it 'lists direct and group-addressed messages, not other people\'s' do
      get '/inbox'

      expect(response.body).to include('Direct hello', 'Staff notice')
      expect(response.body).not_to include('Not yours')
    end

    it 'renders system messages with the DRS sender chip' do
      get '/inbox'
      expect(response.body).to include('inbox-sender--system')
    end

    it 'shows the navbar unread badge' do
      get '/inbox'
      expect(response.body).to include('inbox-nav-link__badge')
    end
  end

  describe 'GET /inbox/:id' do
    before { sign_in staff_user }

    it 'marks the message read via a lazy receipt' do
      message = Message.create!(subject: 'Hi', recipient_nuid: staff_user.nuid)

      expect { get "/inbox/#{message.id}" }.to change(MessageReceipt, :count).by(1)
      expect(MessageReceipt.last.read_at).to be_present
    end

    it 'links in-app paths in the body' do
      message = Message.create!(subject: 'Done', recipient_nuid: staff_user.nuid,
                                body: "Finished.\nView the report: /loaders/marcom/loads/1")

      get "/inbox/#{message.id}"
      expect(response.body).to include('<a href="/loaders/marcom/loads/1">')
    end

    it '404s for a message not addressed to you' do
      message = Message.create!(subject: 'Hi', recipient_nuid: '000000099')

      get "/inbox/#{message.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /inbox' do
    before { sign_in staff_user }

    it 'sends a direct message attributed to the sender' do
      expect do
        post '/inbox', params: { message: { subject: 'Hello', body: 'Hi there', recipient_nuid: '000000003' } }
      end.to change(Message, :count).by(1)

      message = Message.last
      expect(message.sender_nuid).to eq(staff_user.nuid)
      expect(message.recipient_nuid).to eq('000000003')
      expect(response).to redirect_to('/inbox')
    end

    it 'sends a group-addressed message' do
      post '/inbox', params: { message: { subject: 'Notice', recipient_group: 'some:group' } }

      expect(Message.last.recipient_group).to eq('some:group')
    end

    it 'rejects a message with no recipient' do
      post '/inbox', params: { message: { subject: 'Lost', recipient_nuid: '', recipient_group: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Message.count).to eq(0)
    end
  end

  describe 'DELETE /inbox/:id' do
    before { sign_in staff_user }

    it 'soft-dismisses for this user without deleting the row' do
      message = Message.create!(subject: 'Staff notice', recipient_group: 'northeastern:drs:repository:staff')

      delete "/inbox/#{message.id}"

      expect(Message.exists?(message.id)).to be(true)
      expect(Message.inbox_for(staff_user)).not_to include(message)
    end
  end

  describe 'GET /inbox/recipients (typeahead)' do
    before { sign_in staff_user }

    it 'returns prettified directory matches' do
      allow(AtlasRb::User).to receive(:search).with('dav', nuid: staff_user.nuid)
                                              .and_return([{ 'nuid' => '000000004', 'name' => 'Cliff, David' }])

      get '/inbox/recipients', params: { q: 'dav' }

      expect(response.parsed_body).to eq([{ 'nuid' => '000000004', 'name' => 'David Cliff' }])
    end

    it 'returns [] for a blank query without calling Atlas' do
      allow(AtlasRb::User).to receive(:search)

      get '/inbox/recipients', params: { q: ' ' }

      expect(response.parsed_body).to eq([])
      expect(AtlasRb::User).not_to have_received(:search)
    end

    it 'degrades to [] when Atlas is unreachable' do
      allow(AtlasRb::User).to receive(:search).and_raise(Faraday::ConnectionFailed.new('boom'))

      get '/inbox/recipients', params: { q: 'dav' }

      expect(response.parsed_body).to eq([])
    end
  end
end
