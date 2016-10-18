class Loaders::BouveLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    parent = "neu:rx917k992"
    process_new(parent, t('loaders.bouve.short_name'))
  end

  def create
    process_create(t('loaders.bouve.short_name'), "BouveLoadsController", false, false)
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.bouve_loader?
    end
end
