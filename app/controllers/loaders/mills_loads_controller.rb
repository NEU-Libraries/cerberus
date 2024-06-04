class Loaders::MillsLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    process_new(t('loaders.mills.parent'), t('loaders.mills.short_name'))
  end

  def create
    process_create(t('loaders.mills.short_name'), "MillsLoadsController")
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.mills_loader?
    end
end
