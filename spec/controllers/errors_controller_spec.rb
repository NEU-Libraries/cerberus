# frozen_string_literal: true

require 'rails_helper'

describe ErrorsController do
  describe '#forbidden' do
    it 'returns 403' do
      get :forbidden
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe '#not_found' do
    it 'returns 404' do
      get :not_found
      expect(response).to have_http_status(:not_found)
    end
  end

  describe '#gone' do
    it 'returns 410' do
      get :gone
      expect(response).to have_http_status(:gone)
    end
  end

  describe '#internal_server_error' do
    it 'returns 500' do
      get :internal_server_error
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  # An outage that escaped its controller reaches the exceptions app carrying
  # the original exception, and gets the outage page rather than the generic
  # one or the maintenance one.
  describe 'an outage that reached the exceptions app' do
    render_views

    before { request.env['action_dispatch.exception'] = Blacklight::Exceptions::ECONNREFUSED.new }

    it 'renders the outage page at /503' do
      get :service_unavailable

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include 'Search is temporarily unavailable.'
    end

    it 'renders the outage page at /500' do
      get :internal_server_error

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include 'Search is temporarily unavailable.'
    end
  end
end
