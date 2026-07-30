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
  # :privileged, but not in the admin group — the negative control that role
  # alone is not sufficient for the devolved tier.
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000006', name: 'Williams, Susan', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end
  # :privileged + the admin group jointly — the devolved-admin tier (stock
  # pilot user 000000002). Re-parent is one of the five devolved surfaces.
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff', 'northeastern:drs:repository:admin'])
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
        get '/admin/reparent/choose_parent', params: { node_id: 'x' }
        expect(response).to have_http_status(:forbidden)
        get '/admin/reparent/confirm', params: { node_id: 'x' }
        expect(response).to have_http_status(:forbidden)
        post '/admin/reparent/move', params: { node_id: 'x' }
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

  describe 'as a devolved-admin delegate' do
    before { sign_in delegate_user }

    it 'reaches the finder (the gate passes for :privileged + admin group)' do
      get '/admin/reparent'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Re-parent / Move')
    end

    it 'completes a move end-to-end, same as an admin' do
      allow(AtlasRb::Resource).to receive(:find).with('node')
                                                .and_return(atlas_node(noid: 'node', klass: 'Collection', title: 'Node Collection'))
      allow(AtlasRb::Resource).to receive(:find).with('par')
                                                .and_return(atlas_node(noid: 'par', klass: 'Community', title: 'Parent Community'))
      expect(AtlasRb::Collection).to receive(:reparent).with('node', 'par')
                                                       .and_return(OpenStruct.new(id: 'node'))

      post '/admin/reparent/move', params: { node_id: 'node', parent_id: 'par' }

      expect(response).to redirect_to(collection_path('node'))
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

      it 'lists matching containers (with their PID) when q is present' do
        allow(ResourceSearch).to receive(:call)
          .and_return(fake_results(container_doc(noid: 'abc', title: 'Archives Collection')))
        get '/admin/reparent', params: { q: 'arch' }
        expect(response.body).to include('Archives Collection', 'abc')
      end
    end

    describe 'GET choose_parent (step 2)' do
      it 'shows the node being moved and the destination candidates' do
        allow(AtlasRb::Resource).to receive(:find).with('node')
                                                  .and_return(atlas_node(noid: 'node', title: 'Node Collection'))
        allow(ResourceSearch).to receive(:call)
          .and_return(fake_results(container_doc(noid: 'par', title: 'Parent Community', klass: 'Community')))

        get '/admin/reparent/choose_parent', params: { node_id: 'node', node_uuid: 'uuid-node', q: 'par' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Node Collection', 'Parent Community', 'par')
      end

      it 'never offers a top-level / no-parent option, for any node class' do
        %w[Community Collection Work].each do |klass|
          allow(AtlasRb::Resource).to receive(:find)
            .and_return(atlas_node(noid: 'node', klass: klass, title: "A #{klass}"))
          get '/admin/reparent/choose_parent', params: { node_id: 'node' }
          expect(response.body).not_to include('Move to the top level')
          expect(response.body).not_to include('no parent')
        end
      end

      it 'restricts destination candidates to Collections for a Work' do
        allow(AtlasRb::Resource).to receive(:find)
          .and_return(atlas_node(noid: 'wk', klass: 'Work', title: 'A Work'))
        expect(ResourceSearch).to receive(:call)
          .with(hash_including(types: %w[Collection]))
          .and_return(fake_results)

        get '/admin/reparent/choose_parent', params: { node_id: 'wk', q: 'coll' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Collection')
      end
    end

    describe 'GET confirm (step 3)' do
      it 'previews the move from current location to the chosen parent' do
        allow(AtlasRb::Resource).to receive(:find).with('node')
                                                  .and_return(atlas_node(noid: 'node', title: 'Node Collection'))
        allow(AtlasRb::Resource).to receive(:find).with('par')
                                                  .and_return(atlas_node(noid: 'par', klass: 'Community', title: 'Parent Community'))

        get '/admin/reparent/confirm', params: { node_id: 'node', parent_id: 'par' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Confirm move', 'Node Collection', 'Parent Community')
      end

      it 'redirects back to choose_parent when no destination was given' do
        allow(AtlasRb::Resource).to receive(:find).with('node')
                                                  .and_return(atlas_node(noid: 'node', title: 'Node Collection'))

        get '/admin/reparent/confirm', params: { node_id: 'node' }

        expect(response).to redirect_to(admin_reparent_choose_parent_path(node_id: 'node'))
        expect(flash[:alert]).to include('must have a parent')
      end
    end

    describe 'POST move' do
      before do
        allow(AtlasRb::Resource).to receive(:find).with('node')
                                                  .and_return(atlas_node(noid: 'node', klass: 'Collection', title: 'Node Collection'))
        allow(AtlasRb::Resource).to receive(:find).with('par')
                                                  .and_return(atlas_node(noid: 'par', klass: 'Community', title: 'Parent Community'))
      end

      it 'reparents via atlas_rb and redirects to the node page on success' do
        expect(AtlasRb::Collection).to receive(:reparent).with('node', 'par')
                                                         .and_return(OpenStruct.new(id: 'node'))

        post '/admin/reparent/move', params: { node_id: 'node', parent_id: 'par' }

        expect(response).to redirect_to(collection_path('node'))
        expect(flash[:notice]).to include('Node Collection')
      end

      it 're-renders confirm with a generic alert when atlas returns nil' do
        allow(AtlasRb::Collection).to receive(:reparent).and_return(nil)

        post '/admin/reparent/move', params: { node_id: 'node', parent_id: 'par' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Move could not be completed')
      end

      it 'redirects back to choose_parent instead of promoting the node to the top level' do
        post '/admin/reparent/move', params: { node_id: 'node' }

        expect(response).to redirect_to(admin_reparent_choose_parent_path(node_id: 'node'))
        expect(flash[:alert]).to include('must have a parent')
      end

      it 'reparents a Work via AtlasRb::Work.reparent' do
        allow(AtlasRb::Resource).to receive(:find).with('wk')
                                                  .and_return(atlas_node(noid: 'wk', klass: 'Work', title: 'A Work'))
        expect(AtlasRb::Work).to receive(:reparent).with('wk', 'par')
                                                   .and_return(OpenStruct.new(id: 'wk'))

        post '/admin/reparent/move', params: { node_id: 'wk', parent_id: 'par' }

        expect(response).to redirect_to(work_path('wk'))
        expect(flash[:notice]).to include('A Work')
      end
    end
  end
end
