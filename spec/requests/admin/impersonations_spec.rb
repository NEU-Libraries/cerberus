# frozen_string_literal: true

require 'rails_helper'

# Admin::ImpersonationsController — the start/stop toggle for acting-as and
# view-as. Two different gates, not one: view-as/recipients/destroy are
# devolved (User#admin_delegate? passes, mirrors the authz matrix in
# dashboard_spec.rb), while act-as (create_acting_as) stays strictly
# :admin-only regardless of the coarse gate. The state-machine details live
# in spec/controllers/concerns/impersonation_session_spec.rb; this covers the
# HTTP surface: the gate, hydration, session effects, and redirects.
RSpec.describe 'Admin::Impersonations', type: :request do
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
  # pilot user 000000002). View-as (not act-as) is one of the five devolved
  # surfaces.
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff', 'northeastern:drs:repository:admin'])
  end

  # Target hydration: GET /user via AtlasRb::Authentication.login.
  def stub_target(nuid, name: 'Doe, Jane', role: 'privileged', groups: ['northeastern:drs:repository:staff'])
    allow(AtlasRb::Authentication).to receive(:login).with(nuid).and_return(
      AtlasRb::Mash.new('nuid' => nuid, 'name' => name, 'email' => "#{nuid}@neu.edu",
                        'role' => role, 'groups' => groups)
    )
  end

  describe 'authorization gate' do
    context 'as :privileged staff without the admin group' do
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

    context 'as a devolved-admin delegate' do
      before { sign_in delegate_user }

      it 'still rejects POST /admin/act_as with 403 (act-as stays :admin-only)' do
        post admin_act_as_path, params: { nuid: '000000002' }
        expect(response).to have_http_status(:forbidden)
      end

      it 'allows POST /admin/view_as' do
        stub_target('000000003', name: 'Loader, Marcom', role: 'loader',
                                 groups: ['northeastern:drs:repository:loaders:marcom'])
        allow(AtlasRb::AuditEvent).to receive(:emit)

        post admin_view_as_path, params: { nuid: '000000003' }

        expect(response).to redirect_to(root_path)
        expect(session[:view_as_nuid]).to eq('000000003')
      end

      it 'allows GET /admin/impersonation (start surface)' do
        get admin_impersonation_path
        expect(response).to have_http_status(:ok)
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
    it 'renders the start form for an admin in the shared admin-registry chrome (not a well)' do
      sign_in admin_user
      get admin_impersonation_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Target user')
      # Matches the rest of the admin-action UX (Re-parent / Linked members),
      # not the old .well form-section chrome.
      expect(response.body).to include('admin-registry')
      expect(response.body).not_to include('impersonation-start')
      # Target-user typeahead wired to the admin directory endpoint.
      expect(response.body).to include('data-controller="impersonation-search"')
      expect(response.body).to include(admin_impersonation_recipients_path)
      # Full admin: both modes offered.
      expect(response.body).to include('value="Act as"', 'value="View as"', 'Admin-only')
    end

    it 'renders View-as only (no Act-as control) for a devolved-admin delegate' do
      sign_in delegate_user
      get admin_impersonation_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="View as"')
      expect(response.body).not_to include('value="Act as"')
      expect(response.body).to include('Delegated admin access')
      expect(response.body).not_to include('Admin-only')
    end
  end

  describe 'GET /admin/impersonation/recipients (typeahead)' do
    it 'returns prettified directory matches for an admin' do
      sign_in admin_user
      allow(AtlasRb::User).to receive(:search).with('doe', nuid: admin_user.nuid)
                                              .and_return([{ 'nuid' => '000000002', 'name' => 'Doe, Jane' }])

      get admin_impersonation_recipients_path, params: { q: 'doe' }

      expect(response.parsed_body).to eq([{ 'nuid' => '000000002', 'name' => 'Jane Doe' }])
    end

    it 'returns [] for a blank query without calling Atlas' do
      sign_in admin_user
      allow(AtlasRb::User).to receive(:search)

      get admin_impersonation_recipients_path, params: { q: ' ' }

      expect(response.parsed_body).to eq([])
      expect(AtlasRb::User).not_to have_received(:search)
    end

    it 'degrades to [] when Atlas is unreachable' do
      sign_in admin_user
      allow(AtlasRb::User).to receive(:search).and_raise(Faraday::ConnectionFailed.new('boom'))

      get admin_impersonation_recipients_path, params: { q: 'doe' }

      expect(response.parsed_body).to eq([])
    end

    it 'rejects :privileged staff without the admin group with 403' do
      sign_in staff_user
      get admin_impersonation_recipients_path, params: { q: 'doe' }

      expect(response).to have_http_status(:forbidden)
    end

    it 'allows a devolved-admin delegate' do
      sign_in delegate_user
      allow(AtlasRb::User).to receive(:search).with('doe', nuid: delegate_user.nuid)
                                              .and_return([{ 'nuid' => '000000003', 'name' => 'Marcom, Loader' }])

      get admin_impersonation_recipients_path, params: { q: 'doe' }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'as :admin' do
    before do
      sign_in admin_user
      # Starting/ending a session emits a session-scoped AuditEvent; stub the
      # binding so request specs don't reach Atlas. The dedicated context below
      # overrides it to exercise the fail-closed path.
      allow(AtlasRb::AuditEvent).to receive(:emit)
    end

    describe 'POST /admin/act_as' do
      it 'starts an acting-as session and redirects with a notice' do
        stub_target('000000002')
        post admin_act_as_path, params: { nuid: '000000002' }

        expect(session[:acting_as_nuid]).to eq('000000002')
        expect(session[:view_as_nuid]).to be_blank
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to match(/acting as Jane Doe \(000000002\)/)
      end

      it 'records the session start (admin actor, target, mode)' do
        stub_target('000000002')
        post admin_act_as_path, params: { nuid: '000000002' }

        expect(AtlasRb::AuditEvent).to have_received(:emit).with(
          hash_including(action: 'impersonation_started', actor_nuid: admin_user.nuid,
                         on_behalf_of_nuid: '000000002', mode: 'acting_as')
        )
      end

      it 'is fail-closed: an audit-emit failure starts no session and warns' do
        stub_target('000000002')
        allow(AtlasRb::AuditEvent).to receive(:emit).and_raise(Faraday::ConnectionFailed, 'down')

        post admin_act_as_path, params: { nuid: '000000002' }

        expect(session[:acting_as_nuid]).to be_blank
        expect(response).to redirect_to(admin_root_path)
        expect(flash[:alert]).to match(/audit service is unavailable/)
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

  describe 'as a devolved-admin delegate' do
    before do
      sign_in delegate_user
      allow(AtlasRb::AuditEvent).to receive(:emit)
    end

    it 'starts a view-as session, same as an admin' do
      stub_target('000000003', name: 'Loader, Marcom', role: 'loader',
                               groups: ['northeastern:drs:repository:loaders:marcom'])

      post admin_view_as_path, params: { nuid: '000000003' }

      expect(session[:view_as_nuid]).to eq('000000003')
      expect(response).to redirect_to(root_path)
      expect(AtlasRb::AuditEvent).to have_received(:emit).with(
        hash_including(action: 'impersonation_started', actor_nuid: delegate_user.nuid,
                       on_behalf_of_nuid: '000000003', mode: 'view_as')
      )
    end

    it 'never starts an acting-as session, even with a valid target (act-as stays :admin-only)' do
      stub_target('000000003')

      post admin_act_as_path, params: { nuid: '000000003' }

      expect(response).to have_http_status(:forbidden)
      expect(session[:acting_as_nuid]).to be_blank
      expect(AtlasRb::AuditEvent).not_to have_received(:emit)
    end

    it 'ends an active view-as session via DELETE' do
      stub_target('000000003')
      post admin_view_as_path, params: { nuid: '000000003' }
      expect(session[:view_as_nuid]).to eq('000000003')

      delete admin_impersonation_path

      expect(session[:view_as_nuid]).to be_blank
      expect(flash[:notice]).to match(/Impersonation ended/)
    end
  end
end
