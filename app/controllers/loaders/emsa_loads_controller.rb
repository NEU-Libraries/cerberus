class Loaders::EmsaLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    parent = "neu:5m60qx99w"
    process_new(parent, t('loaders.emsa.short_name'))
  end

  def create
    permissions = {"CoreFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:repository:staff", "northeastern:drs:enrollment_management:emc:emc_admin"]}, "ImageSmallFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:repository:staff", "northeastern:drs:enrollment_management:emc:emc_admin"]}, "ImageLargeFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:repository:staff", "northeastern:drs:enrollment_management:emc:emc_admin"]}, "ImageMasterFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:repository:staff", "northeastern:drs:enrollment_management:emc:emc_admin"]}}
    process_create(permissions, t('loaders.emsa.short_name'), "EmsaLoadsController", true)
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.emsa_loader?
    end
end
