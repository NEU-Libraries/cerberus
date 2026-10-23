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
    allow(JobQueueStats).to receive(:call).and_return(jobs)
    allow(PageLatency).to receive(:rows).and_return(pages)
  end

  let(:pages) do
    [PageLatency::Row.new(label: 'Work page', views: 412, usual_ms: 310, slow_ms: 520, mean_ms: 310, atlas_mean_ms: 220)]
  end

  let(:jobs) do
    JobQueueStats::Snapshot.new(waiting_by_queue: { 'default' => 3, 'background' => 9 }, oldest_waiting_at: 25.minutes.ago,
                                running: 2, scheduled: 1, blocked: 0, failed: 4, workers: 1)
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

  # The oldest waiting job is the number that matters: a deep queue that is
  # draining is fine, and an old one means the workers are stuck.
  it 'shows queue depth, the oldest waiting job and failures' do
    sign_in admin
    get '/admin/health'

    expect(response.body).to include('12 waiting · 2 running', 'default 3 · background 9', '25 minutes', 'on 1 live worker')
  end

  it 'says so when the queue database does not answer' do
    allow(JobQueueStats).to receive(:call).and_return(nil)
    sign_in admin
    get '/admin/health'

    expect(response.body).to include 'The job queue database did not answer.'
  end

  # The table a person can read as "how long did the Work page take".
  it 'shows how long each page took, in words, with where the time went' do
    sign_in admin
    get '/admin/health'

    expect(response.body).to include('Page response times', 'Work page', '1 in 20 slower than', '520 ms',
                                     'Atlas 220 ms · page 90 ms')
  end

  it 'says so when there are no page figures' do
    allow(PageLatency).to receive(:rows).and_return(nil)
    sign_in admin
    get '/admin/health'

    expect(response.body).to include 'Redis did not answer, so there are no figures to show.'
  end

  it 'refuses staff' do
    sign_in staff
    get '/admin/health'

    expect(response).to have_http_status(:forbidden)
  end
end
