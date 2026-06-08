# frozen_string_literal: true

require 'rails_helper'

RSpec::Matchers.define_negated_matcher :not_have_enqueued_job, :have_enqueued_job

describe WorksController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml', nuid: '000000004') }
  let(:work) do
    created = AtlasRb::Work.create(collection.id, '/home/cerberus/web/spec/fixtures/files/work-mods.xml', nuid: '000000004')
    AtlasRb::Work.complete(created.id, nuid: '000000004')
    AtlasRb::Work.find(created.id, nuid: '000000004')
  end

  def stub_work_in_progress(work)
    in_progress = AtlasRb::Work.find(work.id, nuid: '000000004')
    in_progress['in_progress'] = true
    allow(AtlasRb::Work).to receive(:find).with(work.id).and_return(in_progress)
  end

  describe 'show' do
    render_views

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
    end

    it 'renders the show partial' do
      expect(work.title).to eq("What's New - How We Respond to Disaster, Episode 1")

      get :show, params: { id: work.id }
      expect(response).to render_template('works/show')
      expect(CGI.unescapeHTML(response.body)).to include(work.title)
    end

    context 'when the work is still in_progress' do
      render_views

      before { stub_work_in_progress(work) }

      it 'flashes the in-progress notice and hides the Edit link' do
        get :show, params: { id: work.id }
        expect(flash.now[:alert]).to eq(WorksController::IN_PROGRESS_NOTICE)
        expect(response.body).not_to match(%r{>\s*Edit\s*</a>})
      end
    end
  end

  describe 'downloads' do
    render_views

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
    end

    it 'renders the downloads turbo-frame without the layout' do
      get :downloads, params: { id: work.id }
      expect(response).to render_template('works/downloads')
      expect(response).not_to render_template(layout: 'application')
      expect(response.body).to include('downloads-modal-frame')
    end
  end

  describe 'create' do
    include ActiveJob::TestHelper

    let(:uuid_re) { /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/ }
    let(:user) { User.new(email: 'depositor@example.com', nuid: '000000004', groups: ['editors']) }

    before { sign_in user }

    it 'enqueues both jobs and redirects to the metadata page' do
      expect do
        post :create, params: { binary:    fixture_file_upload('image.png', 'image/png'),
                                parent_id: collection.id }
      end.to have_enqueued_job(IiifAssetsJob)
        .and have_enqueued_job(ContentCreationJob)
        .with(anything, anything, 'image.png', a_string_matching(uuid_re))

      expect(subject).to redirect_to action: :metadata, id: assigns(:work).id
    end

    it 'does not enqueue the IIIF-assets job for non-image uploads' do
      expect do
        post :create, params: { binary:    fixture_file_upload('plain.txt', 'text/plain'),
                                parent_id: collection.id }
      end.to have_enqueued_job(ContentCreationJob)
        .with(anything, anything, 'plain.txt', a_string_matching(uuid_re))
        .and not_have_enqueued_job(IiifAssetsJob)
    end

    context 'depositor attribution' do
      it 'explicitly attributes to the acting user when upload_as is missing (default)' do
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary:    fixture_file_upload('image.png', 'image/png'),
                                parent_id: collection.id }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: user.nuid)
      end

      it 'explicitly attributes to the acting user when upload_as is "myself"' do
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary:    fixture_file_upload('image.png', 'image/png'),
                                parent_id: collection.id,
                                upload_as: 'myself' }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: user.nuid)
      end

      it 'forwards the parent collection depositor when upload_as is "proxy"' do
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary:    fixture_file_upload('image.png', 'image/png'),
                                parent_id: collection.id,
                                upload_as: 'proxy' }

        expect(AtlasRb::Work).to have_received(:create)
          .with(collection.id, depositor: collection['depositor'])
      end

      it 'attributes wholly to the acting-as target during an impersonation session' do
        # Pure impersonation: even with the radio defaulting to "myself", an
        # active acting-as session overrides — depositor is the target, never
        # the operating admin. (proxy_uploader-empty is enforced Atlas-side.)
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params:  { binary:    fixture_file_upload('image.png', 'image/png'),
                                 parent_id: collection.id,
                                 upload_as: 'myself' },
                      session: { acting_as_nuid: '000000002' }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: '000000002')
      end
    end
  end

  describe 'new' do
    it 'presents the interface to upload a file' do
      get :new
      expect(response).to render_template('works/new')
    end
  end

  describe 'edit' do
    render_views

    let(:user) { User.new(email: 'test@example.com', password: 'password', groups: ['editors']) }

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => ['editors'] } }, nuid: '000000004')
      sign_in user
    end

    it 'renders the edit partial' do
      get :edit, params: { id: work.id }
      expect(response).to render_template('works/edit')
      expect(CGI.unescapeHTML(response.body)).to include(work.title)
    end

    it 'renders the cosmetic group name in the permissions dropdown, not the raw identifier' do
      Group.create!(raw: 'editors', cosmetic: 'Course Editors')

      get :edit, params: { id: work.id }
      body = CGI.unescapeHTML(response.body)

      expect(body).to match(%r{<option[^>]*>\s*Course Editors\s*</option>})
      expect(body).not_to match(%r{<option[^>]*>\s*editors\s*</option>})
    end

    context 'when the work is still in_progress' do
      before { stub_work_in_progress(work) }

      it 'redirects to show with the in-progress alert' do
        get :edit, params: { id: work.id }
        expect(response).to redirect_to(work_path(work.id))
        expect(flash[:alert]).to eq(WorksController::IN_PROGRESS_NOTICE)
      end
    end

    context 'audit history tab' do
      let(:history_envelope) do
        AtlasRb::Mash.new('resource_id' => work.id, 'events' => [])
      end
      let(:admin_user) do
        User.new(email: 'admin@example.com', nuid: '000000004', groups: [], role: 'admin')
      end

      before do
        allow(AtlasRb::Resource).to receive(:history).and_return(history_envelope)
      end

      it 'renders the History tab for Atlas :admin users (no group stuffing required)' do
        sign_in admin_user
        get :edit, params: { id: work.id }
        expect(response.body).to match(/<button[^>]*id="history-tab"/)
        expect(response.body).to include('Audit log')
      end

      it 'does not render the History tab for non-admin editors' do
        get :edit, params: { id: work.id }
        expect(response.body).not_to match(/<button[^>]*id="history-tab"/)
        expect(response.body).not_to include('Audit log')
      end
    end
  end

  describe 'metadata' do
    render_views

    let(:user) { User.new(email: 'test@example.com', password: 'password', groups: ['editors']) }

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => ['editors'] } }, nuid: '000000004')
      sign_in user
    end

    it 'renders the metadata form prefilled with the title and the permissions section' do
      get :metadata, params: { id: work.id }
      expect(response).to render_template('works/metadata')
      body = CGI.unescapeHTML(response.body)
      expect(body).to include('Respond')
      expect(body).to include('Keywords')
      expect(body).to include('General Permissions')
      expect(body).to include('Group Permissions')
      expect(body).to include('id="add-group"')
    end
  end

  describe 'update_metadata' do
    let(:user) { User.new(email: 'test@example.com', password: 'password', nuid: '000000004', groups: ['editors']) }

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => ['editors'] } }, nuid: '000000004')
      sign_in user
    end

    it 'edits the main title without flattening the structured title parts' do
      patch :update_metadata, params: { id: work.id, work: { title: 'NewTitle', description: 'NewAbstract', keywords: "alpha\nbeta" } }

      updated = AtlasRb::Work.find(work.id, nuid: '000000004')
      expect(updated.title).to start_with('NewTitle') # new main title
      expect(updated.title).to include('Respond')     # partName preserved
      expect(updated.title).to include('Episode')     # partNumber preserved
      expect(updated.description).to eq('NewAbstract')
      expect(subject).to redirect_to action: :show, id: work.id
    end

    it 'rejects a save with no keywords (keywords are mandatory)' do
      patch :update_metadata, params: { id: work.id, work: { title: 'NewTitle', description: 'NewAbstract' } }

      expect(flash[:alert]).to be_present
      expect(AtlasRb::Work.find(work.id, nuid: '000000004').title).not_to start_with('NewTitle')
    end
  end

  describe 'tombstone' do
    let(:user) do
      User.new(email: 'staff@example.com', nuid: '000000002',
               groups: [Permissions::STAFF_EDIT_GROUP])
    end

    before do
      AtlasRb::Work.metadata(work.id,
                             { 'permissions' => { 'edit' => [Permissions::STAFF_EDIT_GROUP] } }, nuid: '000000004')
      sign_in user
    end

    it 'calls AtlasRb::Work.tombstone with the acting user nuid and redirects' do
      allow(AtlasRb::Work).to receive(:tombstone)
      post :tombstone, params: { id: work.id }
      expect(AtlasRb::Work).to have_received(:tombstone).with(work.id)
      expect(subject).to redirect_to(root_path)
    end
  end

  describe 'show on a tombstoned work' do
    render_views

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
      tombstoned = AtlasRb::Work.find(work.id, nuid: '000000004')
      tombstoned['tombstoned'] = true
      allow(AtlasRb::Work).to receive(:find).with(work.id).and_return(tombstoned)
    end

    it 'renders the gone template with status 410' do
      get :show, params: { id: work.id }
      expect(response).to render_template('errors/gone')
      expect(response).to have_http_status(:gone)
    end
  end

  describe 'show on a nonexistent work id' do
    render_views

    it 'renders the not_found template with status 404 instead of bubbling a Rails 500' do
      get :show, params: { id: 'does-not-exist-1234' }
      expect(response).to have_http_status(:not_found)
      expect(response).to render_template('errors/not_found')
      expect(CGI.unescapeHTML(response.body)).to include('404')
      expect(CGI.unescapeHTML(response.body)).to include('Not Found')
      # obj_type local picks up the controller name, so the prose is
      # resource-aware rather than the generic "page" default.
      expect(CGI.unescapeHTML(response.body)).to include('the work you requested was not found')
    end
  end
end
