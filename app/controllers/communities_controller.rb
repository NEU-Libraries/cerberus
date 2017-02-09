class CommunitiesController < ApplicationController
  def new
    @set = Community.new
  end

  def create
    if Community.new(community_params).save!
      flash[:notice] = "Community successfully created."
      redirect_to root_path
    else
      flash.now.error = "Error occured creating community."
    end
  end

  private
    def community_params
      params.require(:community).permit(:title, :description)
    end
end
