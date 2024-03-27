# frozen_string_literal: true

class WorksController < ApplicationController
  def show
    # @work = Work.find(params[:id])
    @work = AtlasRb::Work.find(params[:id])
    @mods = AtlasRb::Work.mods(params[:id], 'html')
  end

  def new
    @work = Work.new
    @collection_id = params[:collection_id]
  end

  def create
    file = params[:binary]
    @work = Work.create(
      collection_id: Collection.find(params[:collection_id]).id,
      title: file.original_filename
    )
    BlobCreator.call(work_id: @work.id, path: file.tempfile.path.presence || file.path)
    redirect_to @work
  end
end
