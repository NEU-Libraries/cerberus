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
        expect(response.body).to include('No recorded events.')
      end

      it 'does not render the History tab for non-admin editors' do
        get :edit, params: { id: work.id }
        expect(response.body).not_to match(/<button[^>]*id="history-tab"/)
        expect(response.body).not_to include('No recorded events.')
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
      expect(body).to include(work.title)
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

    it 'updates the title and description and redirects to show' do
      patch :update_metadata, params: { id: work.id, work: { title: 'New Title', description: 'New abstract.' } }

      updated = AtlasRb::Work.find(work.id, nuid: '000000004')
      expect(updated.title).to start_with('New Title')
      expect(updated.title).not_to include("What's New")
      expect(updated.description).to eq('New abstract.')
      expect(subject).to redirect_to action: :show, id: work.id
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
end
