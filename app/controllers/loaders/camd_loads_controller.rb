class Loaders::CamdLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    parent = "neu:f1882040r"
    process_new(parent, t('loaders.camd.short_name'))
  end

  def create
    process_create(t('loaders.camd.short_name'), "CamdLoadsController", false, false)
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.camd_loader?
    end
end
