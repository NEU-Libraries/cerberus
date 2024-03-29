# frozen_string_literal: true

require 'rails_helper'

describe CollectionsController do
  let(:community) { CommunityCreator.call(mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/community-mods.xml')) }
  let(:collection) { CollectionCreator.call(parent_id: community.id, mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/collection-mods.xml')) }

  describe 'edit' do
    render_views
    it 'renders the edit partial' do
      get :edit, params: { id: collection.noid }
      expect(response).to render_template('collections/edit')
      expect(CGI.unescapeHTML(response.body)).to include(collection.decorate.plain_title)
    end
  end

  describe 'show' do
    render_views
    it 'renders the show partial' do
      get :show, params: { id: collection.noid }
      expect(response).to render_template('collections/show')
      expect(CGI.unescapeHTML(response.body)).to include(collection.decorate.plain_title)
    end
  end
end
