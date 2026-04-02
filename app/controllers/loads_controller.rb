# frozen_string_literal: true

class LoadsController < ApplicationController
  before_action :set_load_report, only: [:show, :destroy]

  def index
    @load_reports = LoadReport.order(created_at: :desc)
  end

  def show; end

  def new
    @load_report = LoadReport.new
  end

  def create
    # Phase 2: accept archive, dispatch UnzipJob
    head :not_implemented
  end

  def destroy
    @load_report.destroy
    redirect_to loads_path
  end

  private

    def set_load_report
      @load_report = LoadReport.find(params[:id])
    end
end
