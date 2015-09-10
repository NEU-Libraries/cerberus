class Loaders::MarcomLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    parent = "neu:6240"
    process_new(parent, t('drs.loaders.marcom.short_name'))
  end

  def create
    permissions = {"CoreFile" => {"read"  => ["public"], "edit" => ["northeastern:drs:repository:staff"]}}
    process_create(permissions, t('drs.loaders.multipage.short_name'), "MultipageLoadsController")
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.marcom_loader?
    end
end
