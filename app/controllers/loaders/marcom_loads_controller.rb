class Loaders::MarcomLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    process_new(t('loaders.marcom.parent'), t('loaders.marcom.short_name'))
  end

  def create
    permissions = t('loaders.marcom.permissions')
    process_create(permissions, t('loaders.marcom.short_name'), "MarcomLoadsController", true)
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.marcom_loader?
    end
end
