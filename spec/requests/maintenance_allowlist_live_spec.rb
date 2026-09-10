# frozen_string_literal: true

require 'rails_helper'

# Every entry on MaintenanceGate::SESSION_ONLY_WRITES is a CLAIM: that the
# action reaches no Atlas write, and so can stay open while the repository is
# closed. The inventory spec checks the list matches what we have classified.
# It cannot check whether the claim is TRUE — only Atlas can answer that.
#
# So this file opens a REAL window on the test instance and drives each
# allowlisted route through it. A route that quietly writes gets refused by
# Atlas, atlas_rb raises AtlasRb::ReadOnlyModeError, and the example fails.
# That is how the view-as claim was found to be false.
#
# The window is opened and closed per example, not per file, so a crash strands
# it for one example rather than the run. If one ever does leak, the next run's
# before(:suite) reset deletes the row, and `rake maintenance:close` clears it
# by hand.
RSpec.describe 'The maintenance allowlist, against Atlas', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    User.new(email: 'admin@example.com', password: 'password', nuid: '000000004',
             name: 'Ad, Min', role: 'admin', groups: [Permissions::STAFF_EDIT_GROUP])
  end

  # Opens the window for the duration of the block. `ensure` rather than an
  # after hook so the close runs even when the example raises.
  def with_window
    AtlasRb::Maintenance.write(read_only: true, source: 'operator', message: 'Spec window', retry_after: 30)
    MaintenanceMode.reset_cache!
    yield
  ensure
    AtlasRb::Maintenance.write(read_only: false, source: 'operator')
    MaintenanceMode.reset_cache!
  end

  # The control. If this stops being refused, the window is not really open and
  # every other example in this file is vacuous.
  it 'really does refuse an ordinary write' do
    sign_in admin
    with_window do
      patch "/works/#{SecureRandom.alphanumeric(9)}", params: { work: { title: 'New' } }

      expect(response).to have_http_status(:service_unavailable)
    end
  end

  it 'passes Atlas\'s own Retry-After through to the caller' do
    sign_in admin
    with_window do
      patch "/works/#{SecureRandom.alphanumeric(9)}", params: { work: { title: 'New' } }

      expect(response.headers['Retry-After']).to eq '30'
    end
  end

  describe 'each allowlisted route' do
    it 'lets sign-in through' do
      with_window do
        post '/users/sign_in', params: { user: { nuid: '000000004' } }

        expect(response).not_to have_http_status(:service_unavailable)
      end
    end

    it 'lets sign-out through' do
      sign_in admin
      with_window do
        delete '/users/sign_out'

        expect(response).not_to have_http_status(:service_unavailable)
      end
    end

    it 'lets the NUID sign-in shim through' do
      with_window do
        post '/atlas/process_login', params: { user: { nuid: '000000004' } }

        expect(response).not_to have_http_status(:service_unavailable)
      end
    end

    # Reaches AtlasRb::User.accounts (a read) before deciding the account is
    # not the caller's. It does not reach the Authentication.login on the happy
    # path, so this proves the gate passes and one Atlas read succeeds — not the
    # whole action. Exercising the happy path needs a two-account fixture.
    it 'lets an account switch through' do
      sign_in admin
      with_window do
        post '/accounts/switch', params: { email: 'nobody@example.com' }

        expect(response).not_to have_http_status(:service_unavailable)
      end
    end

    it 'lets a search arrive as a POST' do
      with_window do
        post '/catalog', params: { q: 'river' }

        expect(response).to have_http_status(:ok)
      end
    end

    it 'lets result tracking through' do
      sign_in admin
      with_window do
        post "/catalog/#{SecureRandom.alphanumeric(9)}/track", params: { counter: 1 }

        expect(response).not_to have_http_status(:service_unavailable)
      end
    end

    it 'lets the download queue take an item' do
      sign_in admin
      with_window do
        post '/download_queue/items', params: { id: SecureRandom.alphanumeric(9) }

        expect(response).not_to have_http_status(:service_unavailable)
      end
    end

    # Exiting must always work: the session is torn down BEFORE the end event
    # is emitted, so trapping the admin here would leave them unable to get out
    # of a session they have already left.
    #
    # The session has to be started before the window opens — starting one is
    # itself a write. Without that setup end_impersonation returns early on a
    # nil mode, never emits, and the example passes while proving nothing.
    it 'lets an admin exit an impersonation they are really in' do
      sign_in admin
      post '/admin/view_as', params: { nuid: '000000002' }
      expect(session[:view_as_nuid]).to eq '000000002'

      with_window do
        delete '/admin/impersonation'

        expect(response).not_to have_http_status(:service_unavailable)
      end
    end

    it 'ends the session even so' do
      sign_in admin
      post '/admin/view_as', params: { nuid: '000000002' }

      with_window { delete '/admin/impersonation' }

      expect(session[:view_as_nuid]).to be_nil
    end
  end

  # Starting a view-as is NOT allowlisted, and this is why: it records a
  # session-start AuditEvent in Atlas before establishing the session, and
  # fails closed if that write does not land. It cannot work during a window
  # whatever Cerberus does, so the refusal belongs at the gate where the
  # message is clear.
  it 'refuses to start a view-as, which writes an audit event' do
    sign_in admin
    with_window do
      post '/admin/view_as', params: { nuid: '000000002' }

      expect(response).to have_http_status(:service_unavailable)
      expect(session[:view_as_nuid]).to be_nil
    end
  end

  # Refused at the GATE, not by Atlas. Both produce the same page, but only the
  # gate produces it without a pointless round trip — and only the gate keeps
  # the allowlist honest about which actions write.
  it 'does not even attempt the audit write when it refuses a view-as' do
    sign_in admin
    allow(AtlasRb::AuditEvent).to receive(:emit).and_call_original

    with_window { post '/admin/view_as', params: { nuid: '000000002' } }

    expect(AtlasRb::AuditEvent).not_to have_received(:emit)
  end

  # The nested-window rule, which lives in Atlas: a deploy close must not end a
  # window a person opened by hand. Atlas answers 200 with the UNCHANGED state
  # rather than an error, so a caller that assumes the write took is wrong.
  describe 'the source rule' do
    it 'refuses a deploy close of an operator window, and says so by the state' do
      AtlasRb::Maintenance.write(read_only: true, source: 'operator')

      result = AtlasRb::Maintenance.write(read_only: false, source: 'deploy')

      expect(result.read_only).to be true
      expect(result.source).to eq 'operator'
    ensure
      AtlasRb::Maintenance.write(read_only: false, source: 'operator')
      MaintenanceMode.reset_cache!
    end

    it 'lets an operator close a deploy window' do
      AtlasRb::Maintenance.write(read_only: true, source: 'deploy')

      result = AtlasRb::Maintenance.write(read_only: false, source: 'operator')

      expect(result.read_only).to be false
    ensure
      AtlasRb::Maintenance.write(read_only: false, source: 'operator')
      MaintenanceMode.reset_cache!
    end
  end
end
