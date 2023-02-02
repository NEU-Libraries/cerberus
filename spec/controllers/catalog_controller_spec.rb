# frozen_string_literal: true

require 'rails_helper'

describe CatalogController do
  let!(:community) { CommunityCreator.call(mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/community-mods.xml')) }

  describe 'index' do
    render_views
    it 'renders the index partial' do
      get :index
      expect(response).to render_template('catalog/index')
      expect(CGI.unescapeHTML(response.body)).to include(community.decorate.plain_title)
    end
  end
end
