# frozen_string_literal: true

require 'rails_helper'

# The editor-facing "Request withdraw / move" action on the Work edit page.
# Runs against the live Atlas test backend like the resource controller specs:
# a real Work is created and a real edit ACL granted to the staff group, so the
# authorize_resource_writes! gate (which reads Atlas permissions) is exercised
# end-to-end. The request itself mutates nothing in Atlas — it creates a
# Cerberus StaffRequest row on the admin ledger.
RSpec.describe 'Works request_change', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:fixtures)   { '/home/cerberus/web/spec/fixtures/files' }
  let(:community)  { AtlasRb::Community.create(nil, "#{fixtures}/community-mods.xml", nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, "#{fixtures}/collection-mods.xml", nuid: '000000004') }
  let(:work)       { AtlasRb::Work.create(collection.id, "#{fixtures}/work-mods.xml", nuid: '000000004') }

  let(:editor) do
    User.new(email: 'editor@example.com', password: 'password', nuid: '000000002',
             name: 'Ed, Itor', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end
  let(:outsider) do
    User.new(email: 'outsider@example.com', password: 'password',
             name: 'Out, Sider', role: 'standard', groups: ['randos'])
  end

  def grant_edit!
    AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => [Permissions::STAFF_EDIT_GROUP] } }, nuid: '000000004')
  end

  before { grant_edit! }

  describe 'authorization' do
    # request_change is edit-gated (not the authn-gated create surface), so an
    # unauthenticated caller is a clean 403 — same as PATCH #update.
    it 'forbids the unauthenticated and sends nothing' do
      expect do
        post request_change_work_path(work.id), params: { request_action: 'withdraw' }
      end.not_to change(StaffRequest, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids an authenticated non-editor and sends nothing' do
      sign_in outsider
      expect do
        post request_change_work_path(work.id), params: { request_action: 'withdraw' }
      end.not_to change(StaffRequest, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'as an in-group editor' do
    before { sign_in editor }

    it 'opens a withdraw request on the ledger, snapshotting the title' do
      expect do
        post request_change_work_path(work.id), params: { request_action: 'withdraw', request_note: 'No longer authoritative.' }
      end.to change(StaffRequest, :count).by(1)

      request = StaffRequest.last
      expect(request.kind).to eq('withdraw')
      expect(request.status).to eq('open')
      expect(request.subject_type).to eq('Work')
      expect(request.subject_noid).to eq(work.id)
      expect(request.subject_title).to be_present
      expect(request.requester_nuid).to eq('000000002')
      expect(request.note).to eq('No longer authoritative.')
      expect(request).not_to be_admin_only
      expect(response).to redirect_to(work_path(work.id))
      expect(flash[:notice]).to include('DRS staff')
    end

    # No group-addressed message: fulfilling a request is shared work, and a
    # message is dismissed per person.
    it 'sends no inbox message' do
      expect do
        post request_change_work_path(work.id), params: { request_action: 'withdraw' }
      end.not_to change(Message, :count)
    end

    it 'opens a move request carrying the destination' do
      expect do
        post request_change_work_path(work.id), params: { request_action: 'move', request_note: 'Engineering Theses collection' }
      end.to change(StaffRequest, :count).by(1)

      expect(StaffRequest.last.kind).to eq('move')
      expect(StaffRequest.last.note).to eq('Engineering Theses collection')
    end

    it 'rejects a move with no destination and sends nothing' do
      expect do
        post request_change_work_path(work.id), params: { request_action: 'move', request_note: '' }
      end.not_to change(StaffRequest, :count)
      expect(response).to redirect_to(edit_work_path(work.id))
      expect(flash[:alert]).to include('where this work should move to')
    end

    it 'rejects an unknown request action and sends nothing' do
      expect do
        post request_change_work_path(work.id), params: { request_action: 'destroy_everything' }
      end.not_to change(StaffRequest, :count)
      expect(flash[:alert]).to include('withdrawal or a move')
    end
  end
end
