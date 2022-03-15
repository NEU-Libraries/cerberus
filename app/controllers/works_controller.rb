# frozen_string_literal: true

class WorksController < ApplicationController
  def show
    @work = Work.find(params[:id])
  end

  def new
    @work = Work.new
  end
end
