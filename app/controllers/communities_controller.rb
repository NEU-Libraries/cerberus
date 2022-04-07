# frozen_string_literal: true

class CommunitiesController < ApplicationController
  def show
    @community = Community.find(params[:id])
  end
end
