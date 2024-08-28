# frozen_string_literal: true

require 'rails_helper'

describe CatalogController do
  let!(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml') }

  describe 'index' do
    render_views
    it 'renders the index partial' do
      expect(community['title']).to eq('Northeastern University')
      get :index
      expect(response).to render_template('catalog/index')
      expect(CGI.unescapeHTML(response.body)).to include(community['title'])
    end
  end
end
