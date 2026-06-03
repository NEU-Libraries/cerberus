# frozen_string_literal: true

require 'rails_helper'

describe ImpersonationSession do
  # Minimal controller-shaped host. The concern's `included do` block calls
  # `before_action` / `helper_method`, so the host must answer those as
  # class methods; everything else the concern leans on
  # (session / current_user / request / redirect_to / main_app) is stubbed
  # to isolate the state machine.
  let(:host_class) do
    Class.new do
      def self.before_action(*); end
      def self.helper_method(*); end

      include ImpersonationSession

      attr_accessor :session, :current_user, :request
      attr_reader   :redirected

      def initialize
        @session = {}
      end

      def main_app = self
      def root_path = '/'

      def redirect_to(target, **opts)
        @redirected = { target: target, opts: opts }
      end
    end
  end

  let(:host)  { host_class.new }
  let(:admin) { User.new(nuid: '000000004', groups: ['staff'], role: 'admin') }

  before do
    host.current_user = admin
    # Session start/end emit a session-scoped AuditEvent. Stub it by default;
    # the audit-emission describe asserts/overrides as needed.
    allow(AtlasRb::AuditEvent).to receive(:emit)
  end

  after do
    Current.on_behalf_of = nil
    Current.view_as_nuid = nil
  end

  def stub_login(nuid, role:, groups:)
    allow(AtlasRb::Authentication).to receive(:login).with(nuid).and_return(
      AtlasRb::Mash.new('nuid' => nuid, 'name' => "User #{nuid}", 'email' => "#{nuid}@neu.edu",
                        'role' => role, 'groups' => groups)
    )
  end

  describe 'mode predicates' do
    it 'reports acting-as from the session key' do
      host.session[:acting_as_nuid] = '000000002'
      expect(host.acting_as?).to be(true)
      expect(host.view_as?).to be(false)
      expect(host.impersonating?).to be(true)
    end

    it 'reports view-as from the session key' do
      host.session[:view_as_nuid] = '000000002'
      expect(host.view_as?).to be(true)
      expect(host.acting_as?).to be(false)
    end

    it 'is not impersonating with an empty session' do
      expect(host.impersonating?).to be(false)
    end
  end

  describe '#start_acting_as' do
    it 'sets the acting-as key and stamps the clock' do
      host.start_acting_as('000000002')

      expect(host.acting_as_nuid).to eq('000000002')
      expect(host.session[:impersonation_started_at]).to be_present
      expect(host.session[:impersonation_last_active_at]).to be_present
    end

    it 'ends any live view-as session (mutual exclusion)' do
      host.session[:view_as_nuid] = '000000003'

      host.start_acting_as('000000002')

      expect(host.view_as?).to be(false)
      expect(host.acting_as_nuid).to eq('000000002')
    end
  end

  describe '#start_view_as' do
    it 'ends any live acting-as session (mutual exclusion)' do
      host.session[:acting_as_nuid] = '000000002'

      host.start_view_as('000000003')

      expect(host.acting_as?).to be(false)
      expect(host.view_as_nuid).to eq('000000003')
    end
  end

  describe '#end_impersonation' do
    it 'clears every impersonation session key' do
      host.start_acting_as('000000002')

      host.end_impersonation

      expect(host.session).not_to include(:acting_as_nuid, :view_as_nuid,
                                          :impersonation_started_at, :impersonation_last_active_at)
    end
  end

  describe 'session-audit emission' do
    it 'emits impersonation_started (acting_as) with the admin as actor' do
      host.start_acting_as('000000002')

      expect(AtlasRb::AuditEvent).to have_received(:emit).with(
        action: 'impersonation_started', actor_nuid: admin.nuid,
        on_behalf_of_nuid: '000000002', mode: 'acting_as'
      )
    end

    it 'emits impersonation_started (view_as)' do
      host.start_view_as('000000002')

      expect(AtlasRb::AuditEvent).to have_received(:emit).with(
        action: 'impersonation_started', actor_nuid: admin.nuid,
        on_behalf_of_nuid: '000000002', mode: 'view_as'
      )
    end

    it 'emits impersonation_ended for the active mode on teardown' do
      host.session[:view_as_nuid] = '000000002'

      host.end_impersonation

      expect(AtlasRb::AuditEvent).to have_received(:emit).with(
        action: 'impersonation_ended', actor_nuid: admin.nuid,
        on_behalf_of_nuid: '000000002', mode: 'view_as'
      )
    end

    it 'does not emit on end_impersonation when no session is active' do
      host.end_impersonation
      expect(AtlasRb::AuditEvent).not_to have_received(:emit)
    end

    it 'is FAIL-CLOSED on start: a failed emit leaves no session established' do
      allow(AtlasRb::AuditEvent).to receive(:emit).and_raise(Faraday::ConnectionFailed, 'down')

      expect { host.start_acting_as('000000002') }.to raise_error(Faraday::Error)
      expect(host.acting_as?).to be(false)
    end

    it 'is BEST-EFFORT on end: a failed emit still tears the session down' do
      host.session[:acting_as_nuid] = '000000002'
      allow(AtlasRb::AuditEvent).to receive(:emit).and_raise(Faraday::ConnectionFailed, 'down')

      expect { host.end_impersonation }.not_to raise_error
      expect(host.acting_as?).to be(false)
    end
  end

  describe '#enforce_impersonation_ttl' do
    it 'ends a session idle longer than the TTL' do
      host.session[:acting_as_nuid] = '000000002'
      host.session[:impersonation_last_active_at] = 31.minutes.ago.iso8601

      host.send(:enforce_impersonation_ttl)

      expect(host.acting_as?).to be(false)
    end

    it 'refreshes the clock on a still-active session' do
      host.session[:acting_as_nuid] = '000000002'
      host.session[:impersonation_last_active_at] = 1.minute.ago.iso8601

      host.send(:enforce_impersonation_ttl)

      expect(host.acting_as?).to be(true)
      expect(Time.iso8601(host.session[:impersonation_last_active_at])).to be > 10.seconds.ago
    end

    it 'is a no-op when not impersonating' do
      expect { host.send(:enforce_impersonation_ttl) }.not_to change { host.session }
    end
  end

  describe '#set_impersonation_context' do
    it 'pushes the acting-as target onto Current.on_behalf_of' do
      host.session[:acting_as_nuid] = '000000002'

      host.send(:set_impersonation_context)

      expect(Current.on_behalf_of).to eq('000000002')
    end

    it 'leaves Current.on_behalf_of nil outside an acting-as session' do
      host.send(:set_impersonation_context)
      expect(Current.on_behalf_of).to be_nil
    end
  end

  describe '#effective_user' do
    it 'is the authenticated user when not impersonating' do
      expect(host.effective_user).to eq(admin)
    end

    it 'is the hydrated target during view-as' do
      host.session[:view_as_nuid] = '000000002'
      stub_login('000000002', role: 'guest', groups: ['public-readers'])

      expect(host.effective_user.nuid).to eq('000000002')
      expect(host.effective_user.groups).to eq(['public-readers'])
    end

    it 'fails closed to a least-privilege guest when hydration fails' do
      host.session[:view_as_nuid] = '000000002'
      allow(AtlasRb::Authentication).to receive(:login).and_raise(JSON::ParserError)

      expect(host.effective_user.role).to eq('guest')
      expect(host.effective_user.groups).to eq([])
      expect(host.effective_user.admin?).to be(false)
    end
  end

  describe 'profile hydration' do
    # Regression: a target profile lookup is NOT an on-behalf-of operation.
    # During acting-as, Current.on_behalf_of is set; if it leaked onto the
    # GET /user (whose User: header is the non-admin target), Atlas's
    # admin-gate on the header rejects it and the banner shows "Unknown user".
    it 'suppresses the ambient on_behalf_of for the duration of the lookup' do
      host.session[:acting_as_nuid] = '000000002'
      Current.on_behalf_of = '000000002'
      seen = :unset
      allow(AtlasRb::Authentication).to receive(:login) do
        seen = Current.on_behalf_of
        AtlasRb::Mash.new('nuid' => '000000002', 'name' => 'Doe, Jane', 'role' => 'privileged', 'groups' => [])
      end

      target = host.impersonation_target

      expect(seen).to be_nil # on_behalf_of suppressed inside login
      expect(Current.on_behalf_of).to eq('000000002') # and restored afterwards
      expect(target.pretty_name).to eq('Jane Doe')
    end
  end

  describe '#reject_writes_in_view_as' do
    it 'ends the session and redirects on a non-GET request during view-as' do
      host.session[:view_as_nuid] = '000000002'
      host.request = instance_double('ActionDispatch::Request', get?: false, head?: false)

      host.send(:reject_writes_in_view_as)

      expect(host.view_as?).to be(false)
      expect(host.redirected[:opts][:alert]).to match(/Write attempted during View-as/)
    end

    it 'permits a GET request during view-as' do
      host.session[:view_as_nuid] = '000000002'
      host.request = instance_double('ActionDispatch::Request', get?: true, head?: false)

      host.send(:reject_writes_in_view_as)

      expect(host.view_as?).to be(true)
      expect(host.redirected).to be_nil
    end

    it 'is a no-op outside view-as' do
      host.request = instance_double('ActionDispatch::Request', get?: false, head?: false)
      expect { host.send(:reject_writes_in_view_as) }.not_to(change { host.view_as? })
    end
  end
end
