# frozen_string_literal: true

class LoadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_loader
  before_action :require_loader_role
  before_action :require_loader_group
  before_action :set_load_report, only: [:show, :destroy, :confirm]

  def index
    @load_reports = LoadReport.where(loader: @loader).order(created_at: :desc)
  end

  def show
    # XML and multipage loads pause on a preview the librarian must confirm;
    # build it lazily from the staged archive (no persistence) for the show
    # view to render.
    @preview = preview_service.call(load_report: @load_report) if @load_report.previewing?
  end

  def new
    @load_report  = LoadReport.new
    @destinations = load_destinations
  end

  def create
    archive = params.dig(:load_report, :archive)
    parent  = params.dig(:load_report, :parent_collection_id)
    return reject_missing_archive(parent) if archive.blank?

    @load_report = create_load_report!(archive, parent)
    save_archive(@load_report, archive)
    # IPTC commits straight to the run. XML and multipage stop at a preview
    # the librarian confirms (see #confirm), so they enqueue no job yet —
    # the show view renders the preview from the staged archive.
    UnzipJob.perform_later(@load_report.id) if @loader.iptc?

    # No flash notice — the show page's own state (in-progress spinner for
    # IPTC, the preview card for XML) communicates what happens next, so a
    # redundant banner would only contradict the body once the poll runs.
    redirect_to loader_load_path(@loader, @load_report)
  rescue ActiveRecord::RecordInvalid
    @destinations = load_destinations
    render :new, status: :unprocessable_content
  end

  # Librarian-approved go: flip the staged preview into a real run.
  def confirm
    return redirect_to(loader_load_path(@loader, @load_report)) unless @load_report.previewing?

    @load_report.update!(status: :pending)
    unzip_job.perform_later(@load_report.id)
    redirect_to loader_load_path(@loader, @load_report)
  end

  def destroy
    @load_report.destroy
    redirect_to loader_loads_path(@loader), notice: 'Load report deleted.'
  end

  private

    def create_load_report!(archive, parent)
      LoadReport.create!(
        loader:               @loader,
        creator_nuid:         attributed_nuid,
        source_filename:      archive.original_filename,
        parent_collection_id: parent,
        status:               @loader.iptc? ? :pending : :previewing
      )
    end

    def preview_service
      @loader.multipage? ? MultipagePreview : XmlPreview
    end

    def unzip_job
      @loader.multipage? ? MultipageUnzipJob : XmlUnzipJob
    end

    def reject_missing_archive(parent_id)
      flash.now[:alert]  = 'Please choose an archive file.'
      @load_report       = LoadReport.new(parent_collection_id: parent_id)
      @destinations      = load_destinations
      render :new, status: :unprocessable_content
    end

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

    # Atlas's children endpoint returns child IDs only; resolve them to
    # id+title for the picker in a single batched find_many rather than a
    # find-per-id fan-out. find_many is unordered and may drop unresolvable
    # ids, so index by noid and re-impose the children order.
    def load_destinations
      ids = AtlasRb::Collection.children(@loader.root_collection)
      return [] if ids.blank?

      by_noid = AtlasRb::Resource.find_many(ids).index_by { |n| n['noid'] }
      ids.filter_map { |id| by_noid[id] }
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
