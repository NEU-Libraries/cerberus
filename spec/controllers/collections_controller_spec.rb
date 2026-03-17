# frozen_string_literal: true

require 'rails_helper'

describe CollectionsController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml') }
  let(:collection) { AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml') }

  describe 'edit' do
    render_views

    let(:user) { User.new(email: 'test@example.com', password: 'password', groups: ['editors']) }

    before do
      AtlasRb::Collection.metadata(collection['id'], { 'permissions' => { 'edit' => ['editors'] } })
      sign_in user
    end

    it 'renders the edit partial' do
      get :edit, params: { id: collection['id'] }
      expect(response).to render_template('collections/edit')
      expect(CGI.unescapeHTML(response.body)).to include(collection['title'])
    end
  end

  describe 'show' do
    render_views

    before do
      AtlasRb::Collection.metadata(collection['id'], { 'permissions' => { 'read' => ['public'] } })
    end

    it 'renders the show partial' do
      get :show, params: { id: collection['id'] }
      expect(response).to render_template('collections/show')
      expect(CGI.unescapeHTML(response.body)).to include(collection['title'])
    end
  end

  describe 'new' do
    it 'assigns a open struct to collection' do
      get :new
      expect(assigns(:collection)).to be_a(OpenStruct)
    end

    it 'renders the new partial' do
      get :new
      expect(response).to render_template('collections/new')
    end
  end
end
