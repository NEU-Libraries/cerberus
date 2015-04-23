class Loaders::MarcomController < ApplicationController
  before_filter :authenticate_user!
  before_filter :verify_group

  def new
    @parent = "pid goes here"
    render :template => 'loaders/new'
  end

  def create
  end

  def show
  end

  private

    def verify_group
      # if user is not part of the marcom_loader grouper group, bounce them
    end
end
