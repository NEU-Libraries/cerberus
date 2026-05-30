# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Loaders', type: :request do
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
  let(:marcom_user) do
    User.new(email: 'marcom@example.com', password: 'password',
             nuid: '000000003', name: 'Loader, Marcom', role: 'loader',
             groups: ['northeastern:drs:repository:loaders:marcom'])
  end

  let(:valid_params) do
    {
      loader: {
        slug:            'marcom',
        display_name:    'Marketing and Communications',
        group:           'northeastern:drs:repository:loaders:marcom',
        root_collection: 'neu:6240'
      }
    }
  end

  describe 'authorization gate (admin-only)' do
    %i[admin staff marcom].each_with_object({ admin: :ok, staff: :forbidden, marcom: :forbidden }) do |_, expected|
      # one row per fixture user for each action
    end

    context 'as :admin' do
      before { sign_in admin_user }

      it 'allows GET /admin/loaders' do
        get '/admin/loaders'
        expect(response).to have_http_status(:ok)
      end

      it 'allows GET /admin/loaders/new' do
        get '/admin/loaders/new'
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as :privileged staff' do
      before { sign_in staff_user }

      it 'rejects GET /admin/loaders with 403' do
        get '/admin/loaders'
        expect(response).to have_http_status(:forbidden)
      end

      it 'rejects POST /admin/loaders with 403' do
        post '/admin/loaders', params: valid_params
        expect(response).to have_http_status(:forbidden)
        expect(Loader.count).to eq(0)
      end
    end

    context 'as :loader marcom user' do
      before { sign_in marcom_user }

      it 'rejects GET /admin/loaders with 403' do
        get '/admin/loaders'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'unauthenticated' do
      it 'redirects GET /admin/loaders to sign-in' do
        get '/admin/loaders'
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'CRUD (as admin)' do
    before { sign_in admin_user }

    describe 'POST /admin/loaders' do
      it 'creates a Loader and redirects to index' do
        expect { post '/admin/loaders', params: valid_params }
          .to change(Loader, :count).by(1)
        expect(response).to redirect_to(admin_loaders_path)
      end

      it 'sets a flash notice naming the slug' do
        post '/admin/loaders', params: valid_params
        follow_redirect!
        expect(response.body).to include('marcom')
      end

      it 're-renders :new with 422 on validation error' do
        post '/admin/loaders', params: { loader: valid_params[:loader].merge(slug: '') }
        expect(response).to have_http_status(:unprocessable_content)
        expect(Loader.count).to eq(0)
      end
    end

    describe 'GET /admin/loaders/:slug/edit' do
      let!(:loader) { Loader.create!(valid_params[:loader]) }

      it 'finds by slug (not numeric id)' do
        get "/admin/loaders/#{loader.slug}/edit"
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'PATCH /admin/loaders/:slug' do
      let!(:loader) { Loader.create!(valid_params[:loader]) }

      it 'updates the loader' do
        patch "/admin/loaders/#{loader.slug}",
              params: { loader: { display_name: 'Marketing & Comms' } }
        expect(loader.reload.display_name).to eq('Marketing & Comms')
        expect(response).to redirect_to(admin_loaders_path)
      end

      it 're-renders :edit with 422 on validation error' do
        patch "/admin/loaders/#{loader.slug}",
              params: { loader: { display_name: '' } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
