class Loaders::DamoreLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    parent = "neu:rx913r53s"
    process_new(parent, t('loaders.damore.short_name'))
  end

  def create
    process_create(t('loaders.damore.short_name'), "DamoreLoadsController", false, true)
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.damore_loader?
    end
end
