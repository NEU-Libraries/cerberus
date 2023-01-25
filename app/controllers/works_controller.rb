# frozen_string_literal: true

class WorksController < ApplicationController
  include FileHelper

  def show
    @work = Work.find(params[:id])
  end

  def new
    @work = Work.new
    @collection_id = params[:collection_id]
  end

  def create
    file = params[:binary]
    w = Work.create(
      collection_id: Collection.find(params[:collection_id]).id,
      title: file.original_filename
    )
    BlobCreator.call(work_id: w.id, path: (file.tempfile.path.presence || file.path))
    redirect_to w
  end
end
