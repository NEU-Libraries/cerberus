# frozen_string_literal: true

require 'rails_helper'

describe XmlController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml') }
  let(:collection) { AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml') }
  let(:work) { AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/work-mods.xml') }
  let(:raw_xml) { '<mods><titleInfo><title>Test Title</title></titleInfo></mods>' }

  describe 'editor' do
    render_views
    it 'renders the editor partial' do
      get :editor, params: { id: work['id'] }
      expect(response).to render_template('xml/editor')
    end

    it 'assigns the correct variables' do
      get :editor, params: { id: work['id'] }
      expect(assigns(:resource)).to eq(work)
      expect(assigns(:klass)).to eq('Work')
      expect(assigns(:mods)).to be_present
      expect(assigns(:raw_xml)).to be_present
    end
  end

  describe 'validate' do
    let(:preview_result) { "<div class='mods-preview'><h1>Test Title</h1></div>" }

    before do
      allow(AtlasRb::Resource).to receive(:preview).and_return(preview_result)
    end

    it 'assigns the correct variables' do
      put :validate, params: { resource_id: work['id'], raw_xml: raw_xml }, xhr: true
      expect(assigns(:resource)).to eq(work)
      expect(assigns(:mods)).to eq(preview_result)
      expect(assigns(:mods)).to include('Test Title')
      expect(assigns(:mods)).to be_a(String)
    end
  end

  describe 'update' do
    it 'redirects' do
      put :update, params: { resource_id: work['id'], raw_xml: raw_xml }
      expect(response).to redirect_to(work_path(work['id']))
    end
  end
end
