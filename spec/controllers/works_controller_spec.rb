# frozen_string_literal: true

require 'rails_helper'

describe WorksController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml') }
  let(:collection) { AtlasRb::Collection.create(community.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml') }
  let(:work) { AtlasRb::Work.create(collection.id, '/home/cerberus/web/spec/fixtures/files/work-mods.xml') }

  describe 'show' do
    render_views

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'] } })
    end

    it 'renders the show partial' do
      expect(work.title).to eq("What's New - How We Respond to Disaster, Episode 1")

      get :show, params: { id: work.id }
      expect(response).to render_template('works/show')
      expect(CGI.unescapeHTML(response.body)).to include(work.title)
    end
  end

  describe 'downloads' do
    render_views

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'] } })
    end

    it 'renders the downloads turbo-frame without the layout' do
      get :downloads, params: { id: work.id }
      expect(response).to render_template('works/downloads')
      expect(response).not_to render_template(layout: 'application')
      expect(response.body).to include('downloads-modal-frame')
    end
  end

  describe 'create' do
    it 'uploads a binary and redirects to the metadata page' do
      post :create, params: { binary: fixture_file_upload('image.png', 'image/png'), parent_id: collection.id }
      expect(subject).to redirect_to action: :metadata, id: assigns(:work).id
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
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => ['editors'] } })
      sign_in user
    end

    it 'renders the edit partial' do
      get :edit, params: { id: work.id }
      expect(response).to render_template('works/edit')
      expect(CGI.unescapeHTML(response.body)).to include(work.title)
    end
  end

  describe 'metadata' do
    render_views

    let(:user) { User.new(email: 'test@example.com', password: 'password', groups: ['editors']) }

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => ['editors'] } })
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
    let(:user) { User.new(email: 'test@example.com', password: 'password', groups: ['editors']) }

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => ['editors'] } })
      sign_in user
    end

    it 'updates the title and description and redirects to show' do
      patch :update_metadata, params: { id: work.id, work: { title: 'New Title', description: 'New abstract.' } }

      updated = AtlasRb::Work.find(work.id)
      expect(updated.title).to start_with('New Title')
      expect(updated.title).not_to include("What's New")
      expect(updated.description).to eq('New abstract.')
      expect(subject).to redirect_to action: :show, id: work.id
    end
  end

  describe 'tombstone' do
    let(:user) { User.new(email: 'staff@example.com', nuid: '000000002',
                          groups: [Transformable::STAFF_EDIT_GROUP]) }

    before do
      AtlasRb::Work.metadata(work.id,
                             { 'permissions' => { 'edit' => [Transformable::STAFF_EDIT_GROUP] } })
      sign_in user
    end

    it 'calls AtlasRb::Work.tombstone with the acting user nuid and redirects' do
      allow(AtlasRb::Work).to receive(:tombstone)
      post :tombstone, params: { id: work.id }
      expect(AtlasRb::Work).to have_received(:tombstone).with(work.id, nuid: '000000002')
      expect(subject).to redirect_to(root_path)
    end
  end

  describe 'show on a tombstoned work' do
    render_views

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'] } })
      tombstoned = AtlasRb::Work.find(work.id)
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
