# frozen_string_literal: true

require 'rails_helper'

# What a reader sees when a backing service stops answering. Each service is
# stubbed at the call Cerberus makes, because stopping a real one would fail
# every other example in the run.
RSpec.describe 'Outage pages', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:staff) do
    User.new(email: 'staff@example.com', password: 'password', nuid: '000000002',
             name: 'Staff, Er', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end

  before { MaintenanceMode.reset_cache! }

  describe 'when search is down' do
    before { allow(Blacklight.default_index).to receive(:search).and_raise(Blacklight::Exceptions::ECONNREFUSED) }

    it 'answers 503 and names search, not the service' do
      get '/'

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include 'Search is temporarily unavailable.'
      expect(response.body).not_to include 'Solr'
    end

    it 'asks the caller to come back' do
      get '/'

      expect(response.headers['Retry-After']).to eq Outage::RETRY_AFTER.to_s
    end
  end

  # SystemCallError's === matches on errno alone, so the search handler sees a
  # refusal from any socket. It must not call that a search outage.
  it 'leaves a bare connection refusal to the error page' do
    allow(Blacklight.default_index).to receive(:search).and_raise(Errno::ECONNREFUSED)

    get '/'

    expect(response).to have_http_status(:internal_server_error)
    expect(response.body).to include 'Errno::ECONNREFUSED'
  end

  describe 'when records are down' do
    it 'renders the records page for an Atlas that does not answer' do
      allow(AtlasRb::Work).to receive(:find).and_raise(Faraday::ConnectionFailed.new('refused'))

      get "/works/#{SecureRandom.alphanumeric(9)}"

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include 'Records are temporarily unavailable.'
    end

    # Atlas up, its storage not: the typed 503, which is not a ResourceError and
    # so never reaches Authorizable's refusal handler.
    it 'renders the records page when Atlas reports its own dependency down' do
      allow(AtlasRb::Work).to receive(:find)
        .and_raise(AtlasRb::BackendUnavailableError.new(code: 'backend_unavailable', dependency: 'storage'))

      get "/works/#{SecureRandom.alphanumeric(9)}"

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include 'Records are temporarily unavailable.'
      expect(response.body).not_to include 'storage'
    end

    it 'renders the records page for a gateway status in front of Atlas' do
      gateway = instance_double(Faraday::Response, status: 502, body: '')
      allow(AtlasRb::Work).to receive(:find).and_raise(AtlasRb::ResourceError.new('Bad Gateway', response: gateway))

      get "/works/#{SecureRandom.alphanumeric(9)}"

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include 'Records are temporarily unavailable.'
    end
  end

  # MaintenanceMode holds writes shut when Atlas does not answer. Nobody opened
  # a window, so neither the banner nor the refusal may say maintenance.
  describe 'when the maintenance read finds Atlas unreachable' do
    before do
      allow(AtlasRb::Maintenance).to receive(:read).and_raise(Faraday::ConnectionFailed.new('refused'))
      allow(Blacklight.default_index).to receive(:search).and_return(instance_double(Blacklight::Solr::Response, documents: []))
    end

    it 'shows the outage banner, not the maintenance one' do
      get '/'

      expect(response.body).to include 'Records cannot be opened or saved right now.'
      expect(response.body).not_to include 'Maintenance is under way.'
    end

    it 'refuses a write with the records page' do
      sign_in staff
      post '/sets', params: { set: { title: 'A set' } }

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include 'Records are temporarily unavailable.'
      expect(response.body).not_to include 'read-only'
    end
  end

  # The layout signs the reader in from the database session, so this page
  # must render without it.
  describe 'when the database is down' do
    before { allow(Blacklight.default_index).to receive(:search).and_raise(ActiveRecord::ConnectionNotEstablished) }

    it 'serves the static page without the layout' do
      get '/'

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include Outage::CAPABILITIES[:repository].title
      expect(response.body).not_to include '<link'
    end
  end
end
