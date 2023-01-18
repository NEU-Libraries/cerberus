# frozen_string_literal: true

class WorksController < ApplicationController
  def show
    @work = Work.find(params[:id])
  end

  def new
    @work = Work.new
    @collection_id = params[:collection_id]
  end

  def create
    # TODO: create blob for params[:binary]
    w = WorkCreator.call(parent_id: Collection.find(params[:collection_id]).id)
    w.plain_title = params[:binary].original_filename
    w = Valkyrie.config.metadata_adapter.persister.save(resource: w)
    redirect_to w
  end
end
