# frozen_string_literal: true

require 'rails_helper'

describe WorksController do
  let(:community) { CommunityCreator.call(mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/community-mods.xml')) }
  let(:collection) { CollectionCreator.call(parent_id: community.id, mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/collection-mods.xml')) }
  let(:work) { WorkCreator.call(parent_id: collection.id, mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/work-mods.xml')) }

  describe 'show' do
    render_views
    it 'renders the show partial' do
      get :show, params: { id: work.noid }
      expect(response).to render_template('works/show')
      expect(CGI.unescapeHTML(response.body)).to include(work.plain_title)
    end
  end
end
