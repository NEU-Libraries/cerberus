# frozen_string_literal: true

require 'rails_helper'

describe LoadsController do
  # Views for loads are not yet wired (`app/views/loads/` is empty).
  # The actions are what we're covering here; replace the implicit render
  # with `head :ok` so tests can assert against assigns + status.
  before { allow(controller).to receive(:default_render) { controller.head :ok } }

  describe '#index' do
    it 'returns 200 and assigns load reports newest-first' do
      older = FactoryBot.create(:load_report, created_at: 2.days.ago)
      newer = FactoryBot.create(:load_report, created_at: 1.hour.ago)

      get :index

      expect(response).to have_http_status(:ok)
      expect(assigns(:load_reports).to_a).to eq([newer, older])
    end
  end

  describe '#show' do
    it 'returns 200 and assigns the requested load report' do
      report = FactoryBot.create(:load_report)

      get :show, params: { id: report.id }

      expect(response).to have_http_status(:ok)
      expect(assigns(:load_report)).to eq(report)
    end
  end

  describe '#new' do
    it 'returns 200 and assigns a new load report' do
      get :new

      expect(response).to have_http_status(:ok)
      expect(assigns(:load_report)).to be_a_new(LoadReport)
    end
  end

  describe '#create' do
    it 'returns 501 not implemented (phase 2 stub)' do
      post :create

      expect(response).to have_http_status(:not_implemented)
    end
  end

  describe '#destroy' do
    it 'destroys the report and redirects to loads index' do
      report = FactoryBot.create(:load_report)

      delete :destroy, params: { id: report.id }

      expect(response).to redirect_to(loads_path)
      expect(LoadReport.where(id: report.id)).to be_empty
    end
  end
end
