# frozen_string_literal: true

require 'rails_helper'

describe CollectionsController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml') }
  let(:collection) { AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml') }

  describe 'edit' do
    render_views
    it 'renders the edit partial' do
      get :edit, params: { id: collection['id'] }
      expect(response).to render_template('collections/edit')
      expect(CGI.unescapeHTML(response.body)).to include(collection['title'])
    end
  end

  describe 'show' do
    render_views
    it 'renders the show partial' do
      get :show, params: { id: collection['id'] }
      expect(response).to render_template('collections/show')
      expect(CGI.unescapeHTML(response.body)).to include(collection['title'])
    end
  end
end
