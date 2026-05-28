# frozen_string_literal: true

class LoadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_loader
  before_action :require_loader_role
  before_action :require_loader_group
  before_action :set_load_report, only: [:show, :destroy]

  def index
    @load_reports = LoadReport.where(loader: @loader).order(created_at: :desc)
  end

  def show; end

  def new
    @load_report  = LoadReport.new
    @destinations = load_destinations
  end

  def create
    archive = params.dig(:load_report, :archive)
    parent  = params.dig(:load_report, :parent_collection_id)

    if archive.blank?
      flash.now[:alert] = 'Please choose an archive file.'
      @load_report  = LoadReport.new(parent_collection_id: parent)
      @destinations = load_destinations
      return render :new, status: :unprocessable_entity
    end

    @load_report = LoadReport.new(
      loader:               @loader,
      source_filename:      archive.original_filename,
      parent_collection_id: parent
    )
    @load_report.save!
    save_archive(@load_report, archive)
    UnzipJob.perform_later(@load_report.id)

    redirect_to loader_load_path(@loader, @load_report),
                notice: 'Upload begun — extraction is in progress.'
  rescue ActiveRecord::RecordInvalid
    @destinations = load_destinations
    render :new, status: :unprocessable_entity
  end

  def destroy
    @load_report.destroy
    redirect_to loader_loads_path(@loader), notice: 'Load report deleted.'
  end

  private

    def set_loader
      @loader = Loader.find_by(slug: params[:loader_slug])
      render template: 'errors/not_found', status: :not_found, layout: 'application' if @loader.nil?
    end

    def set_load_report
      @load_report = LoadReport.find_by(id: params[:id], loader: @loader)
      render template: 'errors/not_found', status: :not_found, layout: 'application' if @load_report.nil?
    end

    def require_loader_role
      return if current_user&.role.to_s.in?(%w[loader privileged admin])

      render template: 'errors/forbidden', status: :forbidden, layout: 'application'
    end

    def require_loader_group
      return if current_user&.admin?
      return if @loader && current_user&.groups&.include?(@loader.group)

      render template: 'errors/forbidden', status: :forbidden, layout: 'application'
    end

    # Atlas's children endpoint returns child IDs only; we N+1 the
    # individual finds to get titles for the picker. Acceptable for
    # first cut because the marcom root has <50 children. If this
    # grows, the right fix is an Atlas endpoint that returns
    # id+title (or an atlas_rb helper that batches the finds).
    def load_destinations
      ids = AtlasRb::Collection.children(@loader.root_collection)
      ids.map { |id| AtlasRb::Collection.find(id) }
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.error("LoadsController#load_destinations: #{e.class} #{e.message}")
      []
    end

    # FileUtils.cp against the Rails tempfile path — streaming copy,
    # never File.write(file.read) which would slurp the archive into
    # Ruby memory. Matches WorksController#stage_upload's shape.
    def save_archive(load_report, archive)
      dir = File.join(
        Rails.application.config.x.cerberus.uploads_root,
        'load_reports',
        load_report.id.to_s
      )
      FileUtils.mkdir_p(dir)
      dest = File.join(dir, archive.original_filename)
      FileUtils.cp(archive.tempfile&.path.presence || archive.path, dest)
    end
end
