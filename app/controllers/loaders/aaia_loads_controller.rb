class Loaders::AaiaLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    parent = "neu:cj82n322h"
    process_new(parent, t('loaders.aaia.short_name'))
  end

  def create
    process_create(t('loaders.aaia.short_name'), "AaiaLoadsController", false, false)
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.aaia_loader?
    end
end
