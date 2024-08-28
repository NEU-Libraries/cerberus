# frozen_string_literal: true

require 'rails_helper'

describe XmlController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml') }
  let(:collection) { AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml') }
  let(:work) { AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/work-mods.xml') }

  describe 'editor' do
    render_views
    it 'renders the editor partial' do
      get :editor, params: { id: work['id'] }
      expect(response).to render_template('xml/editor')
    end
  end
end
