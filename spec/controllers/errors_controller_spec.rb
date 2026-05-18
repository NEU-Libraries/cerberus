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
end
