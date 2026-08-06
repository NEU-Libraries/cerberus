# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Loaders', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end
  # :privileged, but not in the admin group.
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000006', name: 'Williams, Susan', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end
  # :privileged + the admin group jointly — the devolved-admin tier (stock
  # pilot user 000000002). Loader definitions is NOT one of the five
  # devolved surfaces; stays :admin-only.
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff', 'northeastern:drs:repository:admin'])
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

    context 'as a devolved-admin delegate (this surface stays :admin-only)' do
      before { sign_in delegate_user }

      it 'rejects GET /admin/loaders with 403' do
        get '/admin/loaders'
        expect(response).to have_http_status(:forbidden)
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

    # A registry row a librarian made to try the documented steps is deletable.
    # One that has run is not: its LoadReports describe Works that outlive it.
    describe 'DELETE /admin/loaders/:slug' do
      let!(:loader) { Loader.create!(valid_params[:loader]) }

      it 'deletes a loader that has never run' do
        expect { delete "/admin/loaders/#{loader.slug}" }
          .to change(Loader, :count).by(-1)
        expect(response).to redirect_to(admin_loaders_path)
      end

      it 'names the deleted slug in the flash' do
        delete "/admin/loaders/#{loader.slug}"
        follow_redirect!
        expect(response.body).to include('marcom')
        expect(response.body).to include('deleted')
      end

      context 'when the loader has run' do
        before { LoadReport.create!(loader: loader, source_filename: 'batch.zip') }

        it 'refuses the delete and keeps the loader' do
          expect { delete "/admin/loaders/#{loader.slug}" }
            .not_to change(Loader, :count)
          expect(response).to redirect_to(admin_loaders_path)
        end

        it 'says how many loads are holding it, not the association wording' do
          delete "/admin/loaders/#{loader.slug}"
          follow_redirect!
          expect(response.body).to include('1 load on record')
          expect(response.body).not_to include('dependent load_reports exist')
        end

        it 'keeps the load report' do
          delete "/admin/loaders/#{loader.slug}"
          expect(LoadReport.count).to eq(1)
        end
      end
    end
  end

  # The registry stays :admin-only for the delete too — it is not one of the
  # devolved-admin surfaces.
  describe 'DELETE authorization' do
    let!(:loader) { Loader.create!(valid_params[:loader]) }

    it 'refuses a :privileged staff user with 403' do
      sign_in staff_user
      delete "/admin/loaders/#{loader.slug}"
      expect(response).to have_http_status(:forbidden)
      expect(Loader.count).to eq(1)
    end

    it 'refuses the devolved-admin tier with 403' do
      sign_in delegate_user
      delete "/admin/loaders/#{loader.slug}"
      expect(response).to have_http_status(:forbidden)
      expect(Loader.count).to eq(1)
    end

    it 'refuses a loader-role user with 403' do
      sign_in marcom_user
      delete "/admin/loaders/#{loader.slug}"
      expect(response).to have_http_status(:forbidden)
      expect(Loader.count).to eq(1)
    end
  end
end
