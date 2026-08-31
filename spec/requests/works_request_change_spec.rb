# frozen_string_literal: true

require 'rails_helper'

# The editor-facing "Request withdraw / move" action on the Work edit page.
# Runs against the live Atlas test backend like the resource controller specs:
# a real Work is created and a real edit ACL granted to the staff group, so the
# authorize_resource_writes! gate (which reads Atlas permissions) is exercised
# end-to-end. The request itself mutates nothing in Atlas — it writes one
# AdminNotice row on the admin ledger.
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
    # Public read alongside the edit grant, so the :edit gate is what the
    # authorization examples exercise. Atlas gates reads on the resource's own
    # ACL, so a private Work is invisible to a guest and the request 404s before
    # reaching the gate — proving the resource is hidden, not that the write is
    # refused. Widening runs top-down; Atlas refuses a resource more visible than
    # its container. Read and edit go in one call, since Atlas assigns the edit
    # grants unconditionally from the payload.
    publicize_ancestry!(community: community, collection: collection)
    AtlasRb::Work.metadata(work.id,
                           { 'permissions' => { 'read' => ['public'],
                                                'edit' => [Permissions::STAFF_EDIT_GROUP] } },
                           nuid: '000000004')
  end

  before { grant_edit! }

  describe 'authorization' do
    # request_change is edit-gated (not the authn-gated create surface), so an
    # unauthenticated caller is a clean 403 — same as PATCH #update.
    it 'forbids the unauthenticated and records nothing' do
      expect do
        post request_change_work_path(work.id), params: { request_action: 'withdraw' }
      end.not_to change(AdminNotice, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids an authenticated non-editor and records nothing' do
      sign_in outsider
      expect do
        post request_change_work_path(work.id), params: { request_action: 'withdraw' }
      end.not_to change(AdminNotice, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'as an in-group editor' do
    before { sign_in editor }

    it 'records a withdraw request, snapshotting the title' do
      expect do
        post request_change_work_path(work.id), params: { request_action: 'withdraw', request_note: 'No longer authoritative.' }
      end.to change(AdminNotice, :count).by(1)

      notice = AdminNotice.last
      expect(notice.kind).to eq('request_withdraw')
      expect(notice).to be_request
      expect(notice.subject_noid).to eq(work.id)
      expect(notice.actor_nuid).to eq('000000002')
      expect(notice.detail(:subject_type)).to eq('Work')
      expect(notice.detail(:subject_title)).to be_present
      expect(notice.detail(:note)).to eq('No longer authoritative.')
      expect(response).to redirect_to(work_path(work.id))
      expect(flash[:notice]).to include('DRS staff')
    end

    # Nothing is addressed to anybody: staff read the ledger, and reply to the
    # depositor off-site.
    it 'sends no inbox message' do
      expect do
        post request_change_work_path(work.id), params: { request_action: 'withdraw' }
      end.not_to change(Message, :count)
    end

    it 'records a move request carrying the destination' do
      expect do
        post request_change_work_path(work.id), params: { request_action: 'move', request_note: 'Engineering Theses collection' }
      end.to change(AdminNotice, :count).by(1)

      expect(AdminNotice.last.kind).to eq('request_move')
      expect(AdminNotice.last.detail(:note)).to eq('Engineering Theses collection')
    end

    it 'rejects a move with no destination and records nothing' do
      expect do
        post request_change_work_path(work.id), params: { request_action: 'move', request_note: '' }
      end.not_to change(AdminNotice, :count)
      expect(response).to redirect_to(edit_work_path(work.id))
      expect(flash[:alert]).to include('where this work should move to')
    end

    it 'rejects an unknown request action and records nothing' do
      expect do
        post request_change_work_path(work.id), params: { request_action: 'destroy_everything' }
      end.not_to change(AdminNotice, :count)
      expect(flash[:alert]).to include('withdrawal or a move')
    end
  end

  # This file leaves Works waiting on a depositor, which the admin triage registry
  # lists. Purging them keeps that registry's own specs measuring its filter rather
  # than the size of the suite (see spec/support/work_cleanup.rb).
  after(:all) { purge_stuck_works! }
end
