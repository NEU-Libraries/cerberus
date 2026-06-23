# frozen_string_literal: true

require 'rails_helper'

describe XmlController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml', nuid: '000000004') }
  let(:work) { AtlasRb::Work.create(collection.id, '/home/cerberus/web/spec/fixtures/files/work-mods.xml', nuid: '000000004') }
  let(:raw_xml) { '<mods><titleInfo><title>Test Title</title></titleInfo></mods>' }

  # The raw-XML editor is now authenticate + edit-gated (audit G1); sign in as
  # the admin who owns the fixtures so every example passes the gate and
  # exercises the editor behaviour as before.
  let(:admin) do
    User.new(email: 'admin@example.com', nuid: '000000004', name: 'Admin, User', role: 'admin', groups: [])
  end

  before { sign_in admin }

  describe 'editor' do
    render_views
    it 'renders the editor partial' do
      get :editor, params: { id: work.id }
      expect(response).to render_template('xml/editor')
    end

    it 'assigns the correct variables' do
      get :editor, params: { id: work.id }
      expect(assigns(:resource)).to eq(work)
      expect(assigns(:klass)).to eq('Work')
      expect(assigns(:mods)).to be_present
      expect(assigns(:raw_xml)).to be_present
    end

    it 'renders a breadcrumb trail ending in the resource and "Edit Work"' do
      get :editor, params: { id: work.id }
      expect(response.body).to include('aria-label="breadcrumb"')
      expect(CGI.unescapeHTML(response.body)).to include(work.title)
      expect(response.body).to include('Edit Work')
    end

    it 'shows the Advanced tab for a Work (links to the edit page advanced pane)' do
      get :editor, params: { id: work.id }
      expect(response.body).to include("#{edit_work_path(work.id)}#advanced")
      expect(response.body).to match(/nav-link[^>]*>\s*Advanced/)
    end

    it 'omits the Advanced tab for a Collection (collections have no advanced fields)' do
      get :editor, params: { id: collection.id }
      expect(response.body).to include('aria-label="breadcrumb"')
      expect(response.body).not_to include('#advanced')
    end

    it 'builds the personal-root-aware trail for a Collection via collection_breadcrumbs' do
      expect(controller).to receive(:collection_breadcrumbs).with(collection.id, editing: true)
      get :editor, params: { id: collection.id }
    end

    it 'uses the structural edit trail for a Work via #breadcrumbs' do
      expect(controller).to receive(:breadcrumbs).with(work.id, editing: true)
      get :editor, params: { id: work.id }
    end
  end

  describe 'validate' do
    let(:preview_result) { "<div class='mods-preview'><h1>Test Title</h1></div>" }

    before do
      allow(AtlasRb::Resource).to receive(:preview).and_return(preview_result)
    end

    context 'when XmlValidator passes' do
      before { allow(XmlValidator).to receive(:call).and_return([]) }

      it 'assigns @errors empty and @mods to the Atlas preview' do
        put :validate, params: { resource_id: work.id, raw_xml: raw_xml }, xhr: true
        expect(assigns(:resource)).to eq(work)
        expect(assigns(:errors)).to eq([])
        expect(assigns(:mods)).to eq(preview_result)
      end
    end

    context 'when XmlValidator returns errors' do
      before { allow(XmlValidator).to receive(:call).and_return(['xmlns:mods missing']) }

      it 'assigns @errors and does not call Atlas preview' do
        put :validate, params: { resource_id: work.id, raw_xml: raw_xml }, xhr: true
        expect(assigns(:errors)).to eq(['xmlns:mods missing'])
        expect(assigns(:mods)).to be_nil
        expect(AtlasRb::Resource).not_to have_received(:preview)
      end
    end
  end

  describe 'update' do
    it 'redirects' do
      put :update, params: { resource_id: work.id, raw_xml: raw_xml }
      expect(response).to redirect_to(work_path(work.id))
    end
  end
end
