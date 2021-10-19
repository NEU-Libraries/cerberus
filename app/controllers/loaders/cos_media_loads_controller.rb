class Loaders::CosMediaLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    process_new(t('loaders.cos_media.parent'), t('loaders.cos_media.short_name'))
  end

  def create
    process_create(t('loaders.cos_media.short_name'), "CosMediaLoadsController")
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.cos_media_loader?
    end
end
