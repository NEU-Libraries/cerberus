# frozen_string_literal: true

require 'rails_helper'

describe WorksController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml') }
  let(:collection) { AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml') }
  let(:work) { AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/work-mods.xml') }

  describe 'show' do
    render_views
    it 'renders the show partial' do
      expect(work['title']).to eq("What's New - How We Respond to Disaster, Episode 1")

      get :show, params: { id: work['id'] }
      expect(response).to render_template('works/show')
      expect(CGI.unescapeHTML(response.body)).to include(work['title'])
    end
  end

  describe 'create' do
    it 'uploads a binary and makes a Work' do
      post :create, params: { binary: fixture_file_upload('image.png', 'image/png'), collection_id: collection['id'] }
      expect(subject).to redirect_to action: :show, id: assigns(:work)['id']
    end
  end

  describe 'new' do
    it 'presents the interface to upload a file' do
      get :new
      expect(response).to render_template('works/new')
    end
  end
end
