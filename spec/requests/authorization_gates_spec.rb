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
  #
  # Public read as well, because Atlas gates reads on the resource's own ACL: a
  # private resource is invisible to anyone outside its read audience, so the
  # request 404s before reaching the gate and proves only that the resource is
  # hidden. These examples exist to prove the gate refuses, so the resource has
  # to be visible to the caller being refused.
  #
  # Widening runs top-down — Atlas refuses a resource more visible than its
  # container — so the containers above the resource go first. A Community has
  # none, and a Collection's is the Community alone.
  def grant_edit!(klass, id)
    publicize_ancestry!(
      community:  (community unless klass == 'Community'),
      collection: (collection if klass == 'Work')
    )
    AtlasRb.const_get(klass).metadata(
      id,
      { 'permissions' => { 'read' => ['public'], 'edit' => [Permissions::STAFF_EDIT_GROUP] } },
      nuid: '000000004'
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

  # G3 — creating a child is a write to its container, so it takes :edit on the
  # DESTINATION, not merely a signed-in session. The destination is a route
  # segment, so no request shape reaches these actions without one.
  #
  # This block previously asserted the opposite — that any authenticated caller
  # could create anywhere — which is the hole it now covers: a signed-in user
  # with no rights on the container was able to create Collections and Works
  # inside it.
  describe 'POST #create (edit on the destination)' do
    # The destination is readable but grants edit to nobody, which is the state
    # these examples need: the caller can see the container and is still refused.
    # Left private, Atlas's read gate hides it and the request 404s before the
    # :edit gate runs, so the example would pass for the wrong reason.
    before { publicize_resource!(AtlasRb::Community, community, '000000004') }

    it 'redirects the unauthenticated to sign in (works)' do
      post collection_works_path(collection.id)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects the unauthenticated to sign in (collections)' do
      post community_collections_path(community.id), params: { collection: { title: 'X', description: 'Y' } }
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects the unauthenticated to sign in (communities)' do
      post community_communities_path(community.id), params: { community: { title: 'X', description: 'Y' } }
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'forbids an authenticated user with no edit rights on the destination' do
      sign_in outsider
      expect(AtlasRb::Collection).not_to receive(:create)

      post community_collections_path(community.id), params: { collection: { title: 'X', description: 'Y' } }

      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids the same user on the GET form, not just the write' do
      sign_in outsider
      get new_community_collection_path(community.id)
      expect(response).to have_http_status(:forbidden)
    end

    it 'admits an editor who holds edit on the destination' do
      grant_edit!('Community', community.id)
      sign_in editor

      post community_collections_path(community.id), params: { collection: { title: 'New Col', description: 'D' } }

      expect(response).not_to redirect_to(new_user_session_path)
      expect(response).not_to have_http_status(:forbidden)
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

      # These examples draw one distinction: admitted or denied. Save refuses
      # XML that does not validate, and this minimal fixture does not, so the
      # validator is stubbed out — otherwise an admitted request answers 422 and
      # stops being distinguishable from a refused one.
      before { allow(XmlValidator).to receive(:call).and_return([]) }

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

      # The gate runs before validation, so a non-editor learns nothing about
      # the document they submitted — same 403 whether it parses or not.
      it 'forbids a non-editor before it looks at the XML' do
        allow(XmlValidator).to receive(:call).and_return(['Opening and ending tag mismatch'])
        sign_in outsider

        put '/xml/update', params: { resource_id: work.id, raw_xml: '<mods><titleInfo></oops>' }

        expect(response).to have_http_status(:forbidden)
      end
    end

    # Repair reads a resource and echoes a cleaned buffer back into the editor.
    # It writes nothing, but it is still a pane of the edit surface and it reads
    # the resource, so it gates with its siblings rather than being treated as
    # harmless. It answers a Turbo Stream, so the admitted example asks for one --
    # a plain HTML request gets 406, which is a format answer, not a gate answer.
    describe 'PUT /xml/repair (echoes a cleaned buffer back into the editor)' do
      let(:dirty_xml) { "<mods><titleInfo><title>Simple#{[0x000B].pack('U')}form</title></titleInfo></mods>" }
      let(:stream) { { 'Accept' => 'text/vnd.turbo-stream.html' } }

      it 'redirects the unauthenticated to sign in' do
        put '/xml/repair', params: { resource_id: work.id, raw_xml: dirty_xml }, headers: stream
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'forbids an authenticated non-editor' do
        sign_in outsider
        put '/xml/repair', params: { resource_id: work.id, raw_xml: dirty_xml }, headers: stream
        expect(response).to have_http_status(:forbidden)
      end

      it 'admits an in-group editor' do
        sign_in editor
        put '/xml/repair', params: { resource_id: work.id, raw_xml: dirty_xml }, headers: stream
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # This file leaves Works waiting on a depositor, which the admin triage registry
  # lists. Purging them keeps that registry's own specs measuring its filter rather
  # than the size of the suite (see spec/support/work_cleanup.rb).
  after(:all) { purge_stuck_works! }
end
