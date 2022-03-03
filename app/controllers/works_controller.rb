# frozen_string_literal: true

class WorksController < ApplicationController
  def show
    @metadata = Work.find(params[:id])
  end
end
