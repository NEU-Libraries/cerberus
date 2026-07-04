# frozen_string_literal: true

require 'rails_helper'

# Authorization regression net for the write surface (audit G1-G3 + the
# deny-by-default `authorize_resource_writes!` macro). Runs against the live
# Atlas test backend like the resource controller specs: real resources are
# created, a real edit ACL is granted to the `editors` group, then each
# mutating action is exercised as
#   (a) logged-out,
#   (b) an authenticated user OUTSIDE the edit group, and
#   (c) an in-group editor.
#
# Policy: Atlas is the enforced write boundary, so these Cerberus gates are the
# UX / defense-in-depth layer — an unauthorized write must be a clean 403 (or a
# sign-in redirect on the authentication-gated create surface), never a
# 200/redirect-to-success. Request specs (not controller specs) so Warden runs.
RSpec.describe 'Authorization gates', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:fixtures)   { '/home/cerberus/web/spec/fixtures/files' }
  let(:community)  { AtlasRb::Community.create(nil, "#{fixtures}/community-mods.xml", nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, "#{fixtures}/collection-mods.xml", nuid: '000000004') }
  let(:work)       { AtlasRb::Work.create(collection.id, "#{fixtures}/work-mods.xml", nuid: '000000004') }

  # The editor is the real Atlas staff user (000000002, in the staff edit
  # group): it must pass BOTH layers — Cerberus's group-ACL check (UI) and
  # Atlas's enforced write authz — so the allowed write actually persists
  # (a 302) rather than 403ing at the Atlas boundary.
  let(:editor) do
    User.new(email: 'editor@example.com', password: 'password', nuid: '000000002',
             name: 'Ed, Itor', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end
  # The outsider is authenticated but outside the edit group, so Cerberus's
  # Ability denies :edit before any Atlas call. No nuid → the permissions READ
  # rides the guest nuid (which exists in the backend), same as the logged-out
  # case; only the Cerberus group check differs.
  let(:outsider) do
    User.new(email: 'outsider@example.com', password: 'password',
             name: 'Out, Sider', role: 'standard', groups: ['randos'])
  end

  # Grant edit to the staff group so the in-group editor passes authorize_edit!
  # (and Atlas authorizes its write); the outsider does not. Set as admin.
  def grant_edit!(klass, id)
    AtlasRb.const_get(klass).metadata(
      id, { 'permissions' => { 'edit' => [Permissions::STAFF_EDIT_GROUP] } }, nuid: '000000004'
    )
  end

  # G2 — the write (#update PATCH), not just the #edit GET form, is edit-gated.
  # Empty params is deliberate on the deny cases: the before_action fires before
  # the action body's params.require, so the gate (not a 400) is what we assert.
  [[:work,       :work_path,       { work: { title: 'Edited', keywords: ['k'] } }],
   [:collection, :collection_path, { collection: { title: 'Edited' } }],
   [:community,  :community_path,  { community: { title: 'Edited' } }]].each do |resource_method, path_helper, edit_payload|
    describe "PATCH #{path_helper} (#{resource_method} #update)" do
      let(:resource) { send(resource_method) }

      before { grant_edit!(resource_method.to_s.classify, resource.id) }

      it 'forbids the unauthenticated (was: form-gated only, write open)' do
        patch send(path_helper, resource.id), params: {}
        expect(response).to have_http_status(:forbidden)
      end

      it 'forbids an authenticated non-editor' do
        sign_in outsider
        patch send(path_helper, resource.id), params: {}
        expect(response).to have_http_status(:forbidden)
      end

      it 'admits an in-group editor (write proceeds, not a 403)' do
        sign_in editor
        patch send(path_helper, resource.id), params: edit_payload
        expect(response).not_to have_http_status(:forbidden)
        expect(response).to have_http_status(:found)
      end
    end
  end

  # G3 — create requires authentication (Cerberus has no :create ability; Atlas
  # enforces role/parent rights, so the Cerberus gate is authn for a clean
  # sign-in redirect rather than a raw Atlas error).
  describe 'POST #create (authentication required)' do
    it 'redirects the unauthenticated to sign in (works)' do
      post works_path, params: { parent_id: collection.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects the unauthenticated to sign in (collections)' do
      post collections_path, params: { parent_id: community.id, collection: { title: 'X', description: 'Y' } }
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects the unauthenticated to sign in (communities)' do
      post communities_path, params: { parent_id: community.id, community: { title: 'X', description: 'Y' } }
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'lets an authenticated user past the auth gate (collections)' do
      sign_in editor
      post collections_path, params: { parent_id: community.id, collection: { title: 'New Col', description: 'D' } }
      expect(response).not_to redirect_to(new_user_session_path)
    end
  end

  # G1 — the raw-XML editor was fully ungated; now authenticate + edit-gate,
  # handling the editor (params[:id]) vs validate/update (params[:resource_id])
  # param split.
  describe 'XML editor' do
    before { grant_edit!('Work', work.id) }

    describe 'GET /xml/editor/:id' do
      it 'redirects the unauthenticated to sign in' do
        get xml_editor_path(work.id)
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'forbids an authenticated non-editor' do
        sign_in outsider
        get xml_editor_path(work.id)
        expect(response).to have_http_status(:forbidden)
      end

      it 'renders for an in-group editor' do
        sign_in editor
        get xml_editor_path(work.id)
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'PUT /xml/update (persists raw MODS to any id — was unauthenticated)' do
      let(:raw_xml) { '<mods><titleInfo><title>Edited via XML</title></titleInfo></mods>' }

      it 'redirects the unauthenticated to sign in (no write)' do
        put '/xml/update', params: { resource_id: work.id, raw_xml: raw_xml }
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'forbids an authenticated non-editor (no write)' do
        sign_in outsider
        put '/xml/update', params: { resource_id: work.id, raw_xml: raw_xml }
        expect(response).to have_http_status(:forbidden)
      end

      it 'admits an in-group editor' do
        sign_in editor
        put '/xml/update', params: { resource_id: work.id, raw_xml: raw_xml }
        expect(response).to redirect_to(work_path(work.id))
      end
    end
  end
end
