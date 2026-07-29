# frozen_string_literal: true

require 'rails_helper'

# Mirrors spec/requests/admin/dashboard_spec.rb: the surface is devolved —
# :admin and the devolved-admin tier (User#admin_delegate?) both pass;
# :privileged staff without the admin group gets 403, and the unauthenticated
# are redirected to sign-in. Purely local reads (ImpressionsReport,
# Cerberus's own TimescaleDB rollups), so no Atlas dependency either way.
RSpec.describe 'Admin::Impressions', type: :request do
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
  # pilot user 000000002). Usage analytics is one of the five devolved surfaces.
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff', 'northeastern:drs:repository:admin'])
  end

  describe 'authorization gate' do
    it 'renders the dashboard for an admin' do
      sign_in admin_user
      get '/admin/impressions'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Usage analytics')
    end

    it 'renders the dashboard for a devolved-admin delegate' do
      sign_in delegate_user
      get '/admin/impressions'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Usage analytics')
    end

    it 'forbids :privileged staff without the admin group with 403' do
      sign_in staff_user
      get '/admin/impressions'

      expect(response).to have_http_status(:forbidden)
    end

    it 'redirects the unauthenticated to sign-in' do
      get '/admin/impressions'

      expect(response).to have_http_status(:found)
    end
  end

  describe 'export' do
    before { sign_in admin_user }

    it 'streams CSV' do
      get '/admin/impressions/export.csv'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/csv')
    end

    it 'streams Excel' do
      get '/admin/impressions/export.xlsx'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    end
  end
end
