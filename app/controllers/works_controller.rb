# frozen_string_literal: true

class WorksController < ApplicationController
  include Thumbable
  include Transformable

  before_action :authorize_show!, only: [:show]
  before_action :authorize_edit!, only: [:edit]

  def show
    @work = AtlasRb::Work.find(params[:id])
    @mods = AtlasRb::Work.mods(params[:id], 'html')
    @files = AtlasRb::Work.files(params[:id])
    breadcrumbs(params[:id])
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

    redirect_to work_path(@work.id)
  end

  def update
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
