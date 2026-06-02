# frozen_string_literal: true

require 'rails_helper'

# Admin linked-members surface: find a Work → manage its linked collections
# (add / remove). atlas_rb + the resource search are stubbed; these exercise the
# Cerberus controller/view wiring, not Atlas or Solr.
RSpec.describe 'Admin::LinkedMembers', type: :request do
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

  def doc(noid:, title:, klass: 'Collection')
    SolrDocument.new('id'                      => "uuid-#{noid}",
                     'alternate_ids_tesim'     => ["id-#{noid}"],
                     'internal_resource_tesim' => klass,
                     'title_tsim'              => [title])
  end

  def fake_results(*docs)
    instance_double(Blacklight::Solr::Response, documents: docs)
  end

  def work_resource(noid:, title: 'A Work', home: 'neu:home')
    OpenStruct.new(
      klass:    'Work',
      resource: OpenStruct.new(id: noid, title: title, ancestors: [[home, 'Collection']])
    )
  end

  describe 'admin gate' do
    context 'as :privileged staff' do
      before { sign_in staff_user }

      it 'forbids every action' do
        get '/admin/linked_members'
        expect(response).to have_http_status(:forbidden)
        get '/admin/linked_members/manage', params: { work_id: 'neu:w' }
        expect(response).to have_http_status(:forbidden)
        post '/admin/linked_members/add', params: { work_id: 'neu:w', collection_id: 'neu:c' }
        expect(response).to have_http_status(:forbidden)
        delete '/admin/linked_members/remove', params: { work_id: 'neu:w', collection_id: 'neu:c' }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'unauthenticated' do
      it 'redirects to sign-in' do
        get '/admin/linked_members'
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'as admin' do
    before { sign_in admin_user }

    describe 'GET index' do
      it 'finds works by keyword' do
        allow(ResourceSearch).to receive(:call)
          .and_return(fake_results(doc(noid: 'neu:w1', title: 'A Photograph', klass: 'Work')))
        get '/admin/linked_members', params: { q: 'photo' }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('A Photograph', 'neu:w1')
      end
    end

    describe 'GET manage' do
      before do
        allow(AtlasRb::Resource).to receive(:find).with('neu:w1').and_return(work_resource(noid: 'neu:w1'))
        allow(AtlasRb::Work).to receive(:linked_members).with('neu:w1').and_return(['neu:linked'])
        allow(AtlasRb::Collection).to receive(:find).and_return(OpenStruct.new(title: 'Linked Collection'))
      end

      it 'lists the collections the work is currently surfaced in, with a remove control' do
        get '/admin/linked_members/manage', params: { work_id: 'neu:w1' }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Linked Collection', 'neu:linked', 'Remove')
      end

      it 'offers Add for an unplaced candidate but marks an already-placed one' do
        allow(ResourceSearch).to receive(:call).and_return(
          fake_results(doc(noid: 'neu:new', title: 'Fresh Collection'),
                       doc(noid: 'neu:linked', title: 'Linked Collection'))
        )
        get '/admin/linked_members/manage', params: { work_id: 'neu:w1', q: 'coll' }
        expect(response.body).to include('Fresh Collection', 'Add')
        expect(response.body).to include('Already placed') # the already-linked candidate
      end
    end

    describe 'POST add' do
      it 'adds a linked membership and redirects back to manage' do
        expect(AtlasRb::Work).to receive(:add_linked_member).with('neu:w1', 'neu:c')
        post '/admin/linked_members/add', params: { work_id: 'neu:w1', collection_id: 'neu:c' }
        expect(response).to redirect_to(admin_linked_members_manage_path(work_id: 'neu:w1'))
      end
    end

    describe 'DELETE remove' do
      it 'removes a linked membership and redirects back to manage' do
        expect(AtlasRb::Work).to receive(:remove_linked_member).with('neu:w1', 'neu:c')
        delete '/admin/linked_members/remove', params: { work_id: 'neu:w1', collection_id: 'neu:c' }
        expect(response).to redirect_to(admin_linked_members_manage_path(work_id: 'neu:w1'))
      end
    end
  end
end
