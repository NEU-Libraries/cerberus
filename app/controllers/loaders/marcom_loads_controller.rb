class Loaders::MarcomLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    process_new(t('loaders.marcom.parent'), t('loaders.marcom.short_name'))
  end

  def create
    permissions = {"CoreFile" => {"read"  => ["northeastern:drs:faculty", "northeastern:drs:staff"], "edit" => ["northeastern:drs:marketing_and_communications:staff", "northeastern:drs:repository:staff"]}, "ImageSmallFile" => {"read"  => ["northeastern:drs:faculty", "northeastern:drs:staff"], "edit" => ["northeastern:drs:marketing_and_communications:staff", "northeastern:drs:repository:staff"]}, "ImageLargeFile" => {"read"  => ["northeastern:drs:faculty", "northeastern:drs:staff"], "edit" => ["northeastern:drs:marketing_and_communications:staff", "northeastern:drs:repository:staff"]}, "ImageMasterFile" => {"read"  => ["northeastern:drs:faculty", "northeastern:drs:staff"], "edit" => ["northeastern:drs:marketing_and_communications:staff", "northeastern:drs:repository:staff"]}}
    process_create(permissions, t('loaders.marcom.short_name'), "MarcomLoadsController", false, true)
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.marcom_loader?
    end
end
