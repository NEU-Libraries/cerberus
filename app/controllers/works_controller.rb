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
    # TODO: create blob for params[:binary]
    file = params[:binary]
    w = WorkCreator.call(parent_id: Collection.find(params[:collection_id]).id)
    w.plain_title = file.original_filename
    w = Valkyrie.config.metadata_adapter.persister.save(resource: w)

    # TODO: Get classification from file path - path -> mime type -> image/video etc.
    create_blob((file.tempfile.path.presence || file.path))

    redirect_to w
  end

  private

    def create_blob(path, work_id)
      fs = FileSetCreator.call(work_id: work_id, classification: Classification.generic)
      b = Valkyrie.config.metadata_adapter.persister.save(resource: Blob.new).id
      b.file_identifiers += [create_file(path, fs).id]
    end
end
