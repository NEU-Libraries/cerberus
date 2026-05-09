# frozen_string_literal: true

class WorksController < ApplicationController
  include Thumbable
  include Transformable

  before_action :authorize_show!, only: [:downloads]
  before_action :authorize_edit!, only: [:edit, :metadata, :update_metadata]
  before_action :authorize_tombstone!, only: [:tombstone]

  def show
    @work = AtlasRb::Work.find(params[:id])
    return render_gone(@work) if @work.tombstoned

    authorize_show!
    @mods = AtlasRb::Work.mods(params[:id], 'html')
    @files = AtlasRb::Work.files(params[:id])
    @can_tombstone = current_ability.can?(:tombstone,
                                          solr_doc_from_permissions(@permissions, klass: 'Work'))
    breadcrumbs(params[:id])
  end

  def tombstone
    AtlasRb::Work.tombstone(params[:id], nuid: current_user.nuid)
    redirect_to root_path, notice: 'Work deleted.'
  end

  def downloads
    @files = AtlasRb::Work.files(params[:id])
    render layout: false
  end

  def new
    @work = Work.new
    @collection_id = params[:collection_id]
  end

  def edit
    @work = AtlasRb::Work.find(params[:id])
    form_preparation(@permissions)
  end

  def create
    # TODO: add support for pdf/word thumbnails
    file = params[:binary]
    @work = AtlasRb::Work.create(AtlasRb::Collection.find(params[:parent_id]).id)

    AtlasRb::Work.metadata(@work.id, title: file.original_filename)
    process_blob(file)

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

    def process_blob(file)
      if file.content_type.start_with?('image/')
        AtlasRb::Work.metadata(@work.id,
                               'thumbnail' => ThumbnailCreator.call(path: file.tempfile.path))
      end

      # BlobCreator will make a fileset to contain the blob
      AtlasRb::Blob.create(@work.id, file.tempfile.path.presence || file.path, file.original_filename)
    end
end
