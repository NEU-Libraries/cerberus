# frozen_string_literal: true

require 'rails_helper'

# What the gate does once the window is open. The window's *state* is stubbed
# at MaintenanceMode, Cerberus's own seam: Atlas enforces the refusal itself and
# specs that end to end, and opening a real window on the shared test instance
# would refuse every other example in the run.
#
# Request specs, not controller specs, so Warden runs.
RSpec.describe 'The maintenance window', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    User.new(email: 'admin@example.com', password: 'password', nuid: '000000004',
             name: 'Ad, Min', role: 'admin', groups: [Permissions::STAFF_EDIT_GROUP])
  end

  let(:staff) do
    User.new(email: 'staff@example.com', password: 'password', nuid: '000000002',
             name: 'Staff, Er', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end

  def open_window!(message: nil, retry_after: nil)
    allow(MaintenanceMode).to receive(:read_only?).and_return(true)
    allow(MaintenanceMode).to receive(:message).and_return(message)
    allow(MaintenanceMode).to receive(:retry_after).and_return(retry_after)
    # The admin page renders the whole window, not just the flag.
    allow(MaintenanceMode).to receive(:window).and_return(
      AtlasRb::Mash.new('read_only' => true, 'source' => 'operator',
                        'since' => '2026-08-25T09:14:00Z', 'message' => message)
    )
  end

  describe 'while it is open' do
    before { open_window! }

    it 'refuses a write with 503 rather than 403' do
      sign_in staff
      patch "/works/#{SecureRandom.alphanumeric(9)}", params: { work: { title: 'New' } }

      expect(response).to have_http_status(:service_unavailable)
    end

    it 'explains the pause on the page it renders' do
      sign_in staff
      post '/sets', params: { set: { title: 'A set' } }

      expect(response.body).to include('read-only')
      expect(response.body).to include('503')
    end

    it 'passes Atlas\'s retry hint to the caller' do
      open_window!(retry_after: 900)
      sign_in staff
      post '/sets', params: { set: { title: 'A set' } }

      expect(response.headers['Retry-After']).to eq '900'
    end

    it 'shows the operator\'s message when they left one' do
      open_window!(message: 'Back at 10:00')
      sign_in staff
      post '/sets', params: { set: { title: 'A set' } }

      expect(response.body).to include('Back at 10:00')
    end

    it 'keeps serving reads' do
      get '/catalog'

      expect(response).to have_http_status(:ok)
    end

    it 'keeps the standing banner in front of everyone' do
      get '/catalog'

      expect(response.body).to include('Read-only')
      expect(response.body).to include('depositing and editing are paused')
    end

    # Blacklight routes search at POST as well as GET. Refusing it would mean a
    # window that stops people searching, which is the opposite of the point.
    it 'still searches when the query arrives as a POST' do
      post '/catalog', params: { q: 'river' }

      expect(response).to have_http_status(:ok)
    end

    it 'still lets someone assemble a download' do
      sign_in staff
      post '/download_queue/items', params: { id: SecureRandom.alphanumeric(9) }

      expect(response).not_to have_http_status(:service_unavailable)
    end

    # The escape hatch. If this ever fails, an open window cannot be closed
    # from the browser, and because MaintenanceMode fails closed on an
    # unreadable flag, that can happen without anyone opening a window at all.
    it 'lets an admin reach the page that closes it' do
      sign_in admin
      get '/admin/maintenance'

      expect(response).to have_http_status(:ok)
    end

    it 'lets an admin close it' do
      allow(MaintenanceMode).to receive(:close!).and_return(AtlasRb::Mash.new('read_only' => false))
      sign_in admin
      delete '/admin/maintenance'

      expect(response).to redirect_to(admin_maintenance_path)
      expect(MaintenanceMode).to have_received(:close!)
    end

    it 'keeps the window off-limits to a non-admin' do
      sign_in staff
      get '/admin/maintenance'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'while it is closed' do
    before { allow(MaintenanceMode).to receive(:read_only?).and_return(false) }

    it 'renders no banner' do
      get '/catalog'

      expect(response.body).not_to include('maintenance-banner')
    end

    it 'lets a write through to its usual gate' do
      sign_in staff
      post '/sets', params: { set: { title: 'A set' } }

      expect(response).not_to have_http_status(:service_unavailable)
    end
  end

  # The backstop. A write that slips past the method gate — a GET-shaped one,
  # or an allowlisted action that grows an Atlas call — must still land on the
  # maintenance page rather than an unhandled exception.
  describe 'when Atlas refuses a write the gate let through' do
    before do
      allow(MaintenanceMode).to receive(:read_only?).and_return(false)
      allow(MaintenanceMode).to receive(:retry_after).and_return(nil)
      allow(AtlasRb::Compilation).to receive(:create)
        .and_raise(AtlasRb::ReadOnlyModeError.new(nil, code: 'read_only_mode'))
    end

    it 'renders the maintenance page' do
      sign_in staff
      post '/sets', params: { set: { title: 'A set' } }

      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
