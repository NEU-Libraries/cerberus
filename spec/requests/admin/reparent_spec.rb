# frozen_string_literal: true

require 'rails_helper'

# The Move / Re-parent finder. Inherits the Admin::BaseController gate (covered
# in the matrix below), then walks index → choose_parent → confirm → move.
# atlas_rb and the container search are stubbed so these exercise the Cerberus
# controller/view wiring, not Atlas or Solr.
RSpec.describe 'Admin::Reparent', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end

  def container_doc(noid:, title:, klass: 'Collection')
    SolrDocument.new('id'                      => "uuid-#{noid}",
                     'alternate_ids_tesim'     => ["id-#{noid}"],
                     'internal_resource_tesim' => klass,
                     'title_tsim'              => [title])
  end

  def fake_results(*docs)
    instance_double(Blacklight::Solr::Response, documents: docs)
  end

  def atlas_node(noid:, klass: 'Collection', title: 'Node', ancestors: [])
    OpenStruct.new(klass:    klass,
                   resource: OpenStruct.new(id: noid, title: title, ancestors: ancestors))
  end

  describe 'admin gate' do
    context 'as :privileged staff' do
      before { sign_in staff_user }

      it 'forbids every step (before_action halts before the body)' do
        get '/admin/reparent'
        expect(response).to have_http_status(:forbidden)
        get '/admin/reparent/choose_parent', params: { node_id: 'neu:x' }
        expect(response).to have_http_status(:forbidden)
        get '/admin/reparent/confirm', params: { node_id: 'neu:x' }
        expect(response).to have_http_status(:forbidden)
        post '/admin/reparent/move', params: { node_id: 'neu:x' }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'unauthenticated' do
      it 'redirects to sign-in' do
        get '/admin/reparent'
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'as admin' do
    before { sign_in admin_user }

    describe 'GET index (step 1)' do
      it 'renders the finder without searching when q is blank' do
        get '/admin/reparent'
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Re-parent / Move')
      end

      it 'lists matching containers (with their NUID) when q is present' do
        allow(ResourceSearch).to receive(:call)
          .and_return(fake_results(container_doc(noid: 'neu:abc', title: 'Archives Collection')))
        get '/admin/reparent', params: { q: 'arch' }
        expect(response.body).to include('Archives Collection', 'neu:abc')
      end
    end

    describe 'GET choose_parent (step 2)' do
      it 'shows the node being moved and the destination candidates' do
        allow(AtlasRb::Resource).to receive(:find).with('neu:node')
                                                  .and_return(atlas_node(noid: 'neu:node', title: 'Node Collection'))
        allow(ResourceSearch).to receive(:call)
          .and_return(fake_results(container_doc(noid: 'neu:par', title: 'Parent Community', klass: 'Community')))

        get '/admin/reparent/choose_parent', params: { node_id: 'neu:node', node_uuid: 'uuid-node', q: 'par' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Node Collection', 'Parent Community', 'neu:par')
      end

      it 'offers the top-level option for a Community' do
        allow(AtlasRb::Resource).to receive(:find)
          .and_return(atlas_node(noid: 'neu:comm', klass: 'Community', title: 'A Community'))
        get '/admin/reparent/choose_parent', params: { node_id: 'neu:comm' }
        expect(response.body).to include('Move to the top level')
      end

      it 'does not offer top-level for a Collection' do
        allow(AtlasRb::Resource).to receive(:find)
          .and_return(atlas_node(noid: 'neu:coll', klass: 'Collection', title: 'A Collection'))
        get '/admin/reparent/choose_parent', params: { node_id: 'neu:coll' }
        expect(response.body).not_to include('Move to the top level')
      end
    end

    describe 'GET confirm (step 3)' do
      it 'previews the move from current location to the chosen parent' do
        allow(AtlasRb::Resource).to receive(:find).with('neu:node')
                                                  .and_return(atlas_node(noid: 'neu:node', title: 'Node Collection'))
        allow(AtlasRb::Resource).to receive(:find).with('neu:par')
                                                  .and_return(atlas_node(noid: 'neu:par', klass: 'Community', title: 'Parent Community'))

        get '/admin/reparent/confirm', params: { node_id: 'neu:node', parent_id: 'neu:par' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Confirm move', 'Node Collection', 'Parent Community')
      end
    end

    describe 'POST move' do
      before do
        allow(AtlasRb::Resource).to receive(:find).with('neu:node')
                                                  .and_return(atlas_node(noid: 'neu:node', klass: 'Collection', title: 'Node Collection'))
        allow(AtlasRb::Resource).to receive(:find).with('neu:par')
                                                  .and_return(atlas_node(noid: 'neu:par', klass: 'Community', title: 'Parent Community'))
      end

      it 'reparents via atlas_rb and redirects to the node page on success' do
        expect(AtlasRb::Collection).to receive(:reparent).with('neu:node', 'neu:par')
                                                         .and_return(OpenStruct.new(id: 'neu:node'))

        post '/admin/reparent/move', params: { node_id: 'neu:node', parent_id: 'neu:par' }

        expect(response).to redirect_to(collection_path('neu:node'))
        expect(flash[:notice]).to include('Node Collection')
      end

      it 're-renders confirm with a generic alert when atlas returns nil' do
        allow(AtlasRb::Collection).to receive(:reparent).and_return(nil)

        post '/admin/reparent/move', params: { node_id: 'neu:node', parent_id: 'neu:par' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Move could not be completed')
      end
    end
  end
end
