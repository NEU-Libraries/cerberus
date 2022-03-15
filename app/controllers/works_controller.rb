# frozen_string_literal: true

class WorksController < ApplicationController
  def show
    @work = Work.find(params[:id])
  end

  def new
    @work = Work.new
  end

  def create
    puts "DGC DEBUG UPLOAD"
    puts params.permit(:binary, :authenticity_token, :commit).inspect
    redirect_to root_path
  end
end
