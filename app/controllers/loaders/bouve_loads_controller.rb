class Loaders::BouveLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    parent = "neu:rx917k992"
    process_new(parent, t('loaders.bouve.short_name'))
  end

  def create
    permissions = {"CoreFile" => {"read"  => ["northeastern:drs:faculty", "northeastern:drs:staff"], "edit" => ["northeastern:drs:bouve:deans_office:media", "northeastern:drs:repository:staff"]}, "ImageMasterFile" => {"read"  => ["northeastern:drs:faculty", "northeastern:drs:staff"], "edit" => ["northeastern:drs:bouve:deans_office:media", "northeastern:drs:repository:staff"]}}
    process_create(permissions, t('loaders.bouve.short_name'), "BouveLoadsController", false)
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.bouve_loader?
    end
end
