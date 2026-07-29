# frozen_string_literal: true

require 'rails_helper'

# Covers the admin actions hub (/admin) and its structure-operation entry
# surfaces. /admin and /admin/reparent are devolved (User#admin_delegate?
# passes, not just :admin); /admin/linked_members stays :admin-only. (Mirrors
# the authz matrix in spec/requests/admin/loaders_spec.rb.)
RSpec.describe 'Admin::Dashboard', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end
  # :privileged, but not in the admin group — the negative control that
  # role alone is not sufficient for the devolved tier.
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000006', name: 'Williams, Susan', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end
  # :privileged + the admin group jointly — the devolved-admin tier
  # (stock pilot user 000000002).
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff', 'northeastern:drs:repository:admin'])
  end

  # path => the icon/label we expect the rendered surface to carry, so the
  # matrix doubles as a light smoke test that the right view rendered.
  devolved_paths = {
    '/admin'          => 'Administration',
    '/admin/reparent' => 'Re-parent / Move'
  }
  admin_only_paths = {
    '/admin/linked_members' => 'Linked members'
  }
  all_paths = devolved_paths.merge(admin_only_paths)

  describe 'authorization gate' do
    context 'as :admin' do
      before { sign_in admin_user }

      all_paths.each do |path, marker|
        it "renders #{path}" do
          get path
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(marker)
        end
      end
    end

    context 'as a devolved-admin delegate (stock pilot user 000000002)' do
      before { sign_in delegate_user }

      devolved_paths.each do |path, marker|
        it "renders #{path}" do
          get path
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(marker)
        end
      end

      admin_only_paths.each_key do |path|
        it "rejects #{path} with 403 (stays :admin-only)" do
          get path
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'as :privileged staff without the admin group' do
      before { sign_in staff_user }

      all_paths.each_key do |path|
        it "rejects #{path} with 403" do
          get path
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'unauthenticated' do
      all_paths.each_key do |path|
        it "redirects #{path} to sign-in" do
          get path
          expect(response).to redirect_to(new_user_session_path)
        end
      end
    end
  end

  describe 'the hub' do
    it 'shows an admin every card, including admin-only ones' do
      sign_in admin_user
      get '/admin'
      expect(response.body).to include(admin_reparent_path, admin_linked_members_path,
                                       admin_impersonation_path, admin_files_path,
                                       admin_groups_path, admin_impressions_path)
    end

    it 'shows a delegate only the devolved cards, not admin-only ones' do
      sign_in delegate_user
      get '/admin'

      expect(response.body).to include(admin_reparent_path, admin_impersonation_path,
                                       admin_files_path, admin_groups_path, admin_impressions_path)
      expect(response.body).not_to include(admin_linked_members_path)
      expect(response.body).to include('Delegated admin access')
      expect(response.body).not_to include('Admin-only')
    end
  end
end
