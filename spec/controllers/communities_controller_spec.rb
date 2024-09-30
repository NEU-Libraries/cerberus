# frozen_string_literal: true

require 'rails_helper'

describe CommunitiesController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml') }

  describe 'edit' do
    render_views
    it 'renders the edit partial' do
      get :edit, params: { id: community['id'] }
      expect(response).to render_template('communities/edit')
      expect(CGI.unescapeHTML(response.body)).to include(community['title'])
    end
  end

  describe 'show' do
    render_views
    it 'renders the show partial' do
      get :show, params: { id: community['id'] }
      expect(response).to render_template('communities/show')
      expect(CGI.unescapeHTML(response.body)).to include(community['title'])
    end
  end

  describe 'new' do
    it 'assigns a open struct to collection' do
      get :new
      expect(assigns(:community)).to be_a(OpenStruct)
    end

    it 'renders the new partial' do
      get :new
      expect(response).to render_template('communities/new')
    end
  end
end
