# frozen_string_literal: true

require 'rails_helper'

# The endpoints Nagios and Swarm poll. HealthCheck is stubbed here; its probes
# are specced in spec/services/health_check_spec.rb.
RSpec.describe 'Health endpoints', type: :request do
  def result(capability, healthy:)
    HealthCheck::Result.new(capability: capability, service: HealthCheck::SERVICES.fetch(capability),
                            ok: healthy, latency_ms: 3, detail: healthy ? nil : 'Faraday::ConnectionFailed: refused')
  end

  def stub_health(down: [])
    results = HealthCheck.capabilities.index_with { |key| result(key, healthy: down.exclude?(key)) }
    allow(HealthCheck).to receive(:call).and_return(results)
    allow(HealthCheck).to receive(:check) { |key| results.fetch(key) }
  end

  describe 'GET /up' do
    # Liveness only. Probing a dependency here would let a Solr outage restart
    # every web container, including the ones serving the outage page.
    it 'answers without asking any dependency' do
      allow(HealthCheck).to receive(:call)

      get '/up'

      expect(response).to have_http_status(:ok)
      expect(HealthCheck).not_to have_received(:call)
    end
  end

  describe 'GET /health' do
    it 'answers 200 with each capability when everything is up' do
      stub_health

      get '/health'

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('status' => 'ok', 'search' => 'ok', 'records' => 'ok')
    end

    it 'answers 503 and names the capability that is down' do
      stub_health(down: [:records])

      get '/health'

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body).to include('status' => 'degraded', 'records' => 'unavailable')
    end

    # Anyone can read this, so it carries capability names and nothing else.
    it 'names no service and quotes no error' do
      stub_health(down: [:records])

      get '/health'

      expect(response.body).not_to match(/Atlas|Solr|Postgres|Cantaloupe|Faraday/)
    end

    it 'tells caches not to keep the answer' do
      stub_health

      get '/health'

      expect(response.headers['Cache-Control']).to include 'no-store'
    end
  end

  describe 'GET /health/:capability' do
    it 'answers a one-word body that check_http can match' do
      stub_health(down: [:search])

      get '/health/search'

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to eq 'unavailable'
    end

    it 'answers 200 and "ok" for a capability that is up' do
      stub_health(down: [:search])

      get '/health/records'

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq 'ok'
    end

    it 'answers 404 for a capability it does not know' do
      stub_health

      get '/health/handles'

      expect(response).to have_http_status(:not_found)
    end
  end
end
