class Loaders::OglLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    parent = "neu:cj82nd192"
    process_new(parent, t('loaders.ogl.short_name'))
  end

  def create
    process_create(t('loaders.ogl.short_name'), "OglLoadsController", false, false)
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.ogl_loader?
    end
end
