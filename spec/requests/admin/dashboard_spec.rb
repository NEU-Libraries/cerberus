# frozen_string_literal: true

require 'rails_helper'

# Covers the admin actions hub (/admin) and its two structure-operation
# entry surfaces. All three inherit Admin::BaseController, so the gate is
# the same: :admin role passes; :privileged staff and other roles get 403;
# the unauthenticated are redirected to sign-in. (Mirrors the authz matrix
# in spec/requests/admin/loaders_spec.rb.)
RSpec.describe 'Admin::Dashboard', type: :request do
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

  # path => the icon/label we expect the rendered surface to carry, so the
  # matrix doubles as a light smoke test that the right view rendered.
  admin_paths = {
    '/admin'                => 'Administration',
    '/admin/reparent'       => 'Re-parent / Move',
    '/admin/linked_members' => 'Linked members'
  }

  describe 'authorization gate (admin-only)' do
    context 'as :admin' do
      before { sign_in admin_user }

      admin_paths.each do |path, marker|
        it "renders #{path}" do
          get path
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(marker)
        end
      end
    end

    context 'as :privileged staff (stock verify user 000000002)' do
      before { sign_in staff_user }

      admin_paths.each_key do |path|
        it "rejects #{path} with 403" do
          get path
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'unauthenticated' do
      admin_paths.each_key do |path|
        it "redirects #{path} to sign-in" do
          get path
          expect(response).to redirect_to(new_user_session_path)
        end
      end
    end
  end

  describe 'the hub' do
    before { sign_in admin_user }

    it 'links to both action surfaces' do
      get '/admin'
      expect(response.body).to include(admin_reparent_path)
      expect(response.body).to include(admin_linked_members_path)
    end
  end
end
