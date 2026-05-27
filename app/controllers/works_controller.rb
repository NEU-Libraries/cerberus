# frozen_string_literal: true

class WorksController < ApplicationController
  include Thumbable
  include Transformable

  IN_PROGRESS_NOTICE = 'This work is still being processed and cannot be edited yet.'

  before_action :authorize_show!, only: [:downloads]
  before_action :authorize_edit!, only: [:edit, :metadata, :update_metadata]
  before_action :authorize_tombstone!, only: [:tombstone]
  before_action :reject_if_in_progress, only: [:edit]

  def show
    @work = AtlasRb::Work.find(params[:id])
    return render_gone(@work) if @work.tombstoned

    authorize_show!
    flash.now[:alert] = IN_PROGRESS_NOTICE if @work.in_progress
    prepare_show_view
  end

  def tombstone
    AtlasRb::Work.tombstone(params[:id])
    redirect_to root_path, notice: 'Work deleted.'
  end

  def downloads
    @files = AtlasRb::Work.assets(params[:id])
    render layout: false
  end

  def new
    @work = Work.new
  end

  def edit
    @work = AtlasRb::Work.find(params[:id])
    form_preparation(@permissions)
  end

  def create
    file = params[:binary]
    parent = AtlasRb::Collection.find(params[:parent_id])
    @work = AtlasRb::Work.create(parent.id, depositor: proxy_depositor(parent))
    AtlasRb::Work.metadata(@work.id, { title: file.original_filename })

    staged_path = stage_upload(file, @work.id)
    enqueue_ingest_jobs(file, staged_path)

    redirect_to metadata_work_path(@work.id), notice: 'File uploaded — please review the metadata.'
  end

  def update
    AtlasRb::Work.metadata(params[:id], work_params)
    redirect_to work_path(params[:id])
  end

  def metadata
    @work = AtlasRb::Work.find(params[:id])
    form_preparation(@permissions)
  end

  def update_metadata
    AtlasRb::Work.metadata(params[:id], work_params)
    redirect_to work_path(params[:id])
  end

  private

    def work_params
      resource_params(:work)
    end

    # Resolve the depositor NUID for a new Work based on the deposit form's
    # "upload as" radio. `"proxy"` → attribute to the collection's depositor
    # (acting user becomes the proxy_uploader server-side); anything else →
    # nil, which leaves Atlas to default the depositor to the acting user.
    def proxy_depositor(parent)
      return nil unless params[:upload_as] == 'proxy'

      parent['depositor'].presence
    end

    def prepare_show_view
      @mods = AtlasRb::Work.mods(params[:id], 'html')
      @files = AtlasRb::Work.assets(params[:id])
      @can_tombstone = current_ability.can?(:tombstone,
                                            solr_doc_from_permissions(@permissions, klass: 'Work'))
      breadcrumbs(params[:id])
    end

    # TODO: add support for pdf/word thumbnails — only images get IIIF derivatives today.
    def enqueue_ingest_jobs(file, staged_path)
      IiifAssetsJob.perform_later(@work.id, staged_path) if file.content_type.to_s.start_with?('image/')
      ContentCreationJob.perform_later(@work.id, staged_path, file.original_filename, SecureRandom.uuid)
    end

    def reject_if_in_progress
      return unless AtlasRb::Work.find(params[:id]).in_progress

      redirect_to work_path(params[:id]), alert: IN_PROGRESS_NOTICE
    end

    def stage_upload(file, work_id)
      dir = File.join(Rails.application.config.x.cerberus.uploads_root, work_id.to_s)
      FileUtils.mkdir_p(dir)
      dest = File.join(dir, file.original_filename)
      FileUtils.cp(file.tempfile.path.presence || file.path, dest)
      dest
    end
end
