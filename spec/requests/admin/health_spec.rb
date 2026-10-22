# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin system health', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    User.new(email: 'admin@example.com', password: 'password', nuid: '000000004',
             name: 'Ad, Min', role: 'admin', groups: [Permissions::STAFF_EDIT_GROUP])
  end

  let(:staff) do
    User.new(email: 'staff@example.com', password: 'password', nuid: '000000002',
             name: 'Staff, Er', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end

  before do
    results = HealthCheck.capabilities.index_with do |key|
      HealthCheck::Result.new(capability: key, service: HealthCheck::SERVICES.fetch(key), ok: key != :records,
                              latency_ms: 5, detail: key == :records ? 'Faraday::ConnectionFailed: refused' : nil)
    end
    allow(HealthCheck).to receive(:call).and_return(results)
  end

  it 'shows an admin each service by name, with the error from the one that is down' do
    sign_in admin
    get '/admin/health'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Atlas', 'Solr', 'Faraday::ConnectionFailed: refused', '1 service down')
  end

  # Someone watching a service come back needs the live answer, not the cache.
  it 'probes afresh' do
    sign_in admin
    get '/admin/health'

    expect(HealthCheck).to have_received(:call).with(fresh: true)
  end

  it 'refuses staff' do
    sign_in staff
    get '/admin/health'

    expect(response).to have_http_status(:forbidden)
  end
end
