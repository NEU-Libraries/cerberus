# frozen_string_literal: true

class WorksController < ApplicationController
  def show
    @work = Work.find(params[:id])
  end

  def new
    @work = Work.new
  end

  def create
    puts params.inspect
    # TODO: create blob for params[:binary]
    # TODO: Assign the file name to the works title
    # TODO: Associate the work with the collection
    w = Valkyrie.config.metadata_adapter.persister.save(resource: Work.new)
    redirect_to w
  end
end
