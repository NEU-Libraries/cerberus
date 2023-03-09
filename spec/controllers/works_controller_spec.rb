# frozen_string_literal: true

require 'rails_helper'

describe WorksController do
  let(:work) { FactoryBot.create_for_repository(:work) }
  let(:community) { CommunityCreator.call(mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/community-mods.xml')) }
  let(:collection) { CollectionCreator.call(parent_id: community.id, mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/collection-mods.xml')) }

  describe 'show' do
    render_views
    it 'renders the show partial' do
      # More complex metadata touches means more decorator coverage
      work.mods_xml = File.read('/home/cerberus/web/spec/fixtures/files/work-mods.xml')
      expect(work.decorate.plain_title).to eq("What's New - How We Respond to Disaster, Episode 1")

      get :show, params: { id: work.noid }
      expect(response).to render_template('works/show')
      expect(CGI.unescapeHTML(response.body)).to include(work.plain_title)
    end
  end

  describe 'create' do
    it 'uploads a binary and makes a Work' do
      post :create, params: { binary: fixture_file_upload('image.png', 'image/png'), collection_id: collection.id }
      expect(subject).to redirect_to action: :show, id: assigns(:work).noid
    end
  end
end
