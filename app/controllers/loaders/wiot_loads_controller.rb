class Loaders::WiotLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    process_new(t('loaders.wiot.parent'), t('loaders.wiot.short_name'))
  end

  def create
    process_create(t('loaders.wiot.short_name'), "WiotLoadsController")
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.wiot_loader?
    end
end
