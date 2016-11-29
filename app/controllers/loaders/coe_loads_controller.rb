class Loaders::CoeLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    parent = "neu:5m60qz05t"
    process_new(parent, t('loaders.coe.short_name'))
  end

  def create
    process_create(t('loaders.coe.short_name'), "CoeLoadsController", false, true)
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.coe_loader?
    end
end
