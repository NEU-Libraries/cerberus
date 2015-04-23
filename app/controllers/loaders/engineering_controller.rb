class Loaders::EngineeringController < ApplicationController
  before_filter :authenticate_user!
  before_filter :verify_group

  def new
  end

  def create
  end

  def show
  end

  private

    def verify_group
      # if user is not part of the engineering_loader grouper group, bounce them
    end
end
