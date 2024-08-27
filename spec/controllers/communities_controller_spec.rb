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
end
