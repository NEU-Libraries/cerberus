# frozen_string_literal: true

class WorksController < ApplicationController
  include ValkyrieHelper

  def show
    @work = Work.find(params[:id])
  end

  def new
    @work = Work.new
  end

  def create
    w = Valkyrie.config.metadata_adapter.persister.save(resource: Work.new)
    redirect_to w
  end
end
