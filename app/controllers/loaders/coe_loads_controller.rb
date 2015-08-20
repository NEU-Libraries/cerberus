class Loaders::CoeLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    parent = "neu:5m60qz05t"
    process_new(parent, t('drs.loaders.coe.short_name'))
  end

  def create
    permissions = {"CoreFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:college_of_engineering:deans_office", "northeastern:drs:repository:staff"]}, "ImageThumbnailFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:college_of_engineering:deans_office", "northeastern:drs:repository:staff"]}, "ImageSmallFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:college_of_engineering:deans_office", "northeastern:drs:repository:staff"]}, "ImageLargeFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:college_of_engineering:deans_office", "northeastern:drs:repository:staff"]}, "ImageMasterFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:college_of_engineering:deans_office", "northeastern:drs:repository:staff"]}}
    process_create(permissions, t('drs.loaders.coe.short_name'), "CoeLoadsController")
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.coe_loader?
    end
end
