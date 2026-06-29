# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Groups', type: :request do
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

  let(:valid_params) do
    { group: { raw: 'northeastern:drs:repository:loaders:marcom', cosmetic: 'Marketing and Communications' } }
  end

  describe 'authorization gate (admin-only)' do
    context 'as :admin' do
      before { sign_in admin_user }

      it 'allows GET /admin/groups' do
        get '/admin/groups'
        expect(response).to have_http_status(:ok)
      end

      it 'allows GET /admin/groups/new' do
        get '/admin/groups/new'
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as :privileged staff' do
      before { sign_in staff_user }

      it 'rejects GET /admin/groups with 403' do
        get '/admin/groups'
        expect(response).to have_http_status(:forbidden)
      end

      it 'rejects POST /admin/groups with 403' do
        post '/admin/groups', params: valid_params
        expect(response).to have_http_status(:forbidden)
        expect(Group.count).to eq(0)
      end
    end

    context 'unauthenticated' do
      it 'redirects GET /admin/groups to sign-in' do
        get '/admin/groups'
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'CRUD (as admin)' do
    before { sign_in admin_user }

    describe 'POST /admin/groups' do
      it 'creates a Group and redirects to index' do
        expect { post '/admin/groups', params: valid_params }
          .to change(Group, :count).by(1)
        expect(response).to redirect_to(admin_groups_path)
      end

      it 'sets a flash notice naming the raw group' do
        post '/admin/groups', params: valid_params
        follow_redirect!
        expect(response.body).to include('northeastern:drs:repository:loaders:marcom')
      end

      it 're-renders :new with 422 on validation error (blank cosmetic)' do
        post '/admin/groups', params: { group: valid_params[:group].merge(cosmetic: '') }
        expect(response).to have_http_status(:unprocessable_content)
        expect(Group.count).to eq(0)
      end

      it 're-renders :new with 422 on a raw value with spaces' do
        post '/admin/groups', params: { group: valid_params[:group].merge(raw: 'not a group') }
        expect(response).to have_http_status(:unprocessable_content)
        expect(Group.count).to eq(0)
      end
    end

    describe 'PATCH /admin/groups/:id' do
      let!(:group) { Group.create!(valid_params[:group]) }

      it 'updates the cosmetic name' do
        patch "/admin/groups/#{group.id}", params: { group: { cosmetic: 'Marketing & Comms' } }
        expect(group.reload.cosmetic).to eq('Marketing & Comms')
        expect(response).to redirect_to(admin_groups_path)
      end

      it 're-renders :edit with 422 on validation error' do
        patch "/admin/groups/#{group.id}", params: { group: { cosmetic: '' } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(group.reload.cosmetic).to eq('Marketing and Communications')
      end
    end

    describe 'DELETE /admin/groups/:id' do
      let!(:group) { Group.create!(valid_params[:group]) }

      it 'removes the Group and redirects to index' do
        expect { delete "/admin/groups/#{group.id}" }
          .to change(Group, :count).by(-1)
        expect(response).to redirect_to(admin_groups_path)
      end
    end
  end

  describe 'pretty_group resolution' do
    it 'renames the group everywhere once a row exists, and falls back without one' do
      expect(ApplicationController.new.pretty_group('northeastern:drs:repository:loaders:marcom'))
        .to eq('northeastern:drs:repository:loaders:marcom')

      Group.create!(valid_params[:group])

      expect(ApplicationController.new.pretty_group('northeastern:drs:repository:loaders:marcom'))
        .to eq('Marketing and Communications')
    end
  end

  describe 'pagination' do
    before { sign_in admin_user }

    it 'shows PER_PAGE rows per page and walks to the next' do
      # raws are zero-padded so the default_scope order is stable across pages.
      26.times { |i| Group.create!(raw: format('grp:%03d', i), cosmetic: "Group #{i}") }

      get '/admin/groups'
      expect(response.body).to include('grp:000')      # first row, page 1
      expect(response.body).not_to include('grp:025')  # 26th row spills to page 2

      get '/admin/groups', params: { page: 2 }
      expect(response.body).to include('grp:025')
    end
  end
end
