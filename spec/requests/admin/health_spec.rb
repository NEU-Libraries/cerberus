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
    allow(AtlasLatency).to receive(:summary).and_return(atlas)
    allow(AtlasLatency).to receive(:served).and_return(served)
    allow(PageLatency).to receive(:rows).and_return(pages)
  end

  let(:pages) do
    [PageLatency::Row.new(label: 'Work page', views: 412, usual_ms: 310, slow_ms: 520, mean_ms: 310, atlas_mean_ms: 220)]
  end

  let(:served) do
    AtlasRb::Mash.new('window_minutes' => 60, 'calls' => 1790, 'server_errors' => 2, 'mean_ms' => 21,
                      'p50_ms' => 14, 'p95_ms' => 97, 'p99_ms' => 205,
                      'slowest_actions' => [{ 'action' => 'works#mods', 'calls' => 120, 'p95_ms' => 188 }])
  end

  let(:jobs) do
    JobQueueStats::Snapshot.new(waiting_by_queue: { 'default' => 3, 'background' => 9 }, oldest_waiting_at: 25.minutes.ago,
                                running: 2, scheduled: 1, blocked: 0, failed: 4, workers: 1)
  end

  let(:atlas) do
    LatencyHistogram::Summary.new(calls: 1840, failed: 3, timeouts: 1, mean_ms: 48, p50_ms: 31, p95_ms: 212, p99_ms: 880,
                                  extra_means: {})
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

  it 'shows Atlas percentiles for the last hour' do
    sign_in admin
    get '/admin/health'

    expect(response.body).to include('1840', '212 ms', '880 ms')
  end

  # The gap between the rows is what happens outside Atlas's Rails app, which is
  # the reason Atlas's own figures are shown at all.
  it "shows Atlas's own figures beside Cerberus's" do
    sign_in admin
    get '/admin/health'

    expect(response.body).to include('Atlas, serving', 'Cerberus, waiting', '97 ms', '212 ms')
  end

  it "lists Atlas's slowest actions" do
    sign_in admin
    get '/admin/health'

    expect(response.body).to include('works#mods', '188 ms')
  end

  it "reads Atlas's figures as the signed-in admin" do
    sign_in admin
    get '/admin/health'

    expect(AtlasLatency).to have_received(:served).with(nuid: '000000004')
  end

  it "keeps Cerberus's row when Atlas cannot give its figures" do
    allow(AtlasLatency).to receive(:served).and_return(nil)
    sign_in admin
    get '/admin/health'

    expect(response.body).to include('Atlas could not give its figures.', '212 ms')
  end

  it 'says so when Redis holds no figures, rather than showing zeros' do
    allow(AtlasLatency).to receive(:summary).and_return(nil)
    sign_in admin
    get '/admin/health'

    expect(response.body).to include 'Redis did not answer'
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

  it 'keeps the Atlas call figures in a closed section below' do
    sign_in admin
    get '/admin/health'

    expect(response.body).to match(%r{<details[^>]*>\s*<summary[^>]*>Behind the pages: Atlas calls</summary>})
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
