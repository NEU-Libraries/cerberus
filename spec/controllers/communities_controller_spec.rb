# frozen_string_literal: true

require 'rails_helper'

describe CommunitiesController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', nuid: '000000004') }

  describe 'edit' do
    render_views

    let(:user) { User.new(email: 'test@example.com', password: 'password', groups: ['editors']) }

    before do
      AtlasRb::Community.metadata(community.id, { 'permissions' => { 'edit' => ['editors'] } }, nuid: '000000004')
      sign_in user
    end

    it 'renders the edit partial' do
      get :edit, params: { id: community.id }
      expect(response).to render_template('communities/edit')
      expect(CGI.unescapeHTML(response.body)).to include(community.title)
    end

    context 'audit history tab' do
      let(:history_envelope) do
        AtlasRb::Mash.new('resource_id' => community.id, 'events' => [])
      end
      let(:admin_user) do
        User.new(email: 'admin@example.com', nuid: '000000004', groups: [], role: 'admin')
      end

      before do
        allow(AtlasRb::Resource).to receive(:history).and_return(history_envelope)
      end

      it 'renders the History tab for Atlas :admin users (no group stuffing required)' do
        sign_in admin_user
        get :edit, params: { id: community.id }
        expect(response.body).to match(/<button[^>]*id="history-tab"/)
        expect(response.body).to include('No recorded events.')
      end

      it 'does not render the History tab for non-admin editors' do
        get :edit, params: { id: community.id }
        expect(response.body).not_to match(/<button[^>]*id="history-tab"/)
        expect(response.body).not_to include('No recorded events.')
      end
    end
  end

  describe 'show' do
    render_views

    before do
      AtlasRb::Community.metadata(community.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
    end

    it 'renders the show partial' do
      get :show, params: { id: community.id }
      expect(response).to render_template('communities/show')
      expect(CGI.unescapeHTML(response.body)).to include(community.title)
    end
  end

  describe 'new' do
    it 'assigns a open struct to community' do
      get :new
      expect(assigns(:community)).to be_a(OpenStruct)
    end

    it 'renders the new partial' do
      get :new
      expect(response).to render_template('communities/new')
    end
  end

  describe 'tombstone' do
    let(:user) do
      User.new(email: 'staff@example.com', nuid: '000000002',
               groups: [Permissions::STAFF_EDIT_GROUP])
    end

    before do
      AtlasRb::Community.metadata(community.id,
                                  { 'permissions' => { 'edit' => [Permissions::STAFF_EDIT_GROUP] } }, nuid: '000000004')
      sign_in user
    end

    it 'calls AtlasRb::Community.tombstone with the acting user nuid and redirects' do
      allow(AtlasRb::Community).to receive(:tombstone)
      post :tombstone, params: { id: community.id }
      expect(AtlasRb::Community).to have_received(:tombstone).with(community.id)
      expect(subject).to redirect_to(root_path)
    end
  end
end
