# frozen_string_literal: true

require 'rails_helper'

# Admin::ImpersonationsController — the start/stop toggle for acting-as and
# view-as. Admin-only gate inherited from Admin::BaseController (mirrors the
# authz matrix in dashboard_spec.rb). The state-machine details live in
# spec/controllers/concerns/impersonation_session_spec.rb; this covers the
# HTTP surface: the gate, hydration, session effects, and redirects.
RSpec.describe 'Admin::Impersonations', type: :request do
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

  # Target hydration: GET /user via AtlasRb::Authentication.login.
  def stub_target(nuid, name: 'Doe, Jane', role: 'privileged', groups: ['northeastern:drs:repository:staff'])
    allow(AtlasRb::Authentication).to receive(:login).with(nuid).and_return(
      AtlasRb::Mash.new('nuid' => nuid, 'name' => name, 'email' => "#{nuid}@neu.edu",
                        'role' => role, 'groups' => groups)
    )
  end

  describe 'authorization gate (admin-only)' do
    context 'as :privileged staff' do
      before { sign_in staff_user }

      it 'rejects POST /admin/act_as with 403' do
        post admin_act_as_path, params: { nuid: '000000002' }
        expect(response).to have_http_status(:forbidden)
      end

      it 'rejects POST /admin/view_as with 403' do
        post admin_view_as_path, params: { nuid: '000000002' }
        expect(response).to have_http_status(:forbidden)
      end

      it 'rejects GET /admin/impersonation (start surface) with 403' do
        get admin_impersonation_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'unauthenticated' do
      it 'redirects POST /admin/act_as to sign-in' do
        post admin_act_as_path, params: { nuid: '000000002' }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /admin/impersonation (start surface)' do
    it 'renders the start form for an admin' do
      sign_in admin_user
      get admin_impersonation_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Target NUID')
    end
  end

  describe 'as :admin' do
    before { sign_in admin_user }

    describe 'POST /admin/act_as' do
      it 'starts an acting-as session and redirects with a notice' do
        stub_target('000000002')
        post admin_act_as_path, params: { nuid: '000000002' }

        expect(session[:acting_as_nuid]).to eq('000000002')
        expect(session[:view_as_nuid]).to be_blank
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to match(/acting as Jane Doe \(000000002\)/)
      end
    end

    describe 'POST /admin/view_as' do
      it 'starts a view-as session and redirects with a notice' do
        stub_target('000000002')
        post admin_view_as_path, params: { nuid: '000000002' }

        expect(session[:view_as_nuid]).to eq('000000002')
        expect(session[:acting_as_nuid]).to be_blank
        expect(flash[:notice]).to match(/viewing as Jane Doe/)
      end
    end

    describe 'mutual exclusion' do
      it 'view-as ends a live acting-as session' do
        stub_target('000000002')
        stub_target('000000003', name: 'Loader, Marcom', role: 'loader',
                                 groups: ['northeastern:drs:repository:loaders:marcom'])

        post admin_act_as_path,  params: { nuid: '000000002' }
        expect(session[:acting_as_nuid]).to eq('000000002')

        post admin_view_as_path, params: { nuid: '000000003' }
        expect(session[:view_as_nuid]).to eq('000000003')
        expect(session[:acting_as_nuid]).to be_blank
      end
    end

    describe 'unknown / blank NUID' do
      it 'refuses to start when hydration fails' do
        allow(AtlasRb::Authentication).to receive(:login).and_raise(JSON::ParserError)
        post admin_act_as_path, params: { nuid: '999999999' }

        expect(session[:acting_as_nuid]).to be_blank
        expect(response).to redirect_to(admin_root_path)
        expect(flash[:alert]).to match(/valid NUID/)
      end

      it 'refuses to start on a blank NUID without calling Atlas' do
        expect(AtlasRb::Authentication).not_to receive(:login)
        post admin_act_as_path, params: { nuid: '' }

        expect(session[:acting_as_nuid]).to be_blank
        expect(flash[:alert]).to match(/valid NUID/)
      end
    end

    describe 'DELETE /admin/impersonation' do
      it 'ends whichever session is active' do
        stub_target('000000002')
        post admin_act_as_path, params: { nuid: '000000002' }
        expect(session[:acting_as_nuid]).to eq('000000002')

        delete admin_impersonation_path
        expect(session[:acting_as_nuid]).to be_blank
        expect(response).to redirect_to(admin_root_path)
        expect(flash[:notice]).to match(/Impersonation ended/)
      end
    end

    # The app-wide reject_writes_in_view_as guard, exercised through the real
    # before_action chain (ApplicationController includes the concern).
    describe 'view-as write guard' do
      before do
        stub_target('000000002')
        post admin_view_as_path, params: { nuid: '000000002' }
        expect(session[:view_as_nuid]).to eq('000000002')
      end

      it 'ends the session on a write to a guarded route, before the action runs' do
        # PATCH /works/:id would hit Atlas in the action — the guard fires
        # first, so no stub is needed and Atlas is never touched.
        patch work_path('anything')

        expect(session[:view_as_nuid]).to be_blank
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to match(/Write attempted during View-as/)
      end

      it 'permits a GET and keeps the session' do
        get admin_root_path # a GET that renders without touching Atlas
        expect(response).to have_http_status(:ok)
        expect(session[:view_as_nuid]).to eq('000000002')
      end

      it 'exempts the impersonation controller so Exit ends cleanly' do
        delete admin_impersonation_path

        expect(session[:view_as_nuid]).to be_blank
        expect(flash[:notice]).to match(/Impersonation ended/)
        expect(flash[:alert]).to be_blank
      end
    end
  end
end
