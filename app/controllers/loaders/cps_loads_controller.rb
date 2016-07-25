class Loaders::CpsLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    parent = "neu:5m60qz16b"
    process_new(parent, t('loaders.cps.short_name'))
  end

  def create
    permissions = {"CoreFile" => {"edit" => ["northeastern:drs:college_of_professional_studies:media", "northeastern:drs:repository:staff"]}, "ImageSmallFile" => {"edit" => ["northeastern:drs:college_of_professional_studies:media", "northeastern:drs:repository:staff"]}, "ImageLargeFile" => {"edit" => ["northeastern:drs:college_of_professional_studies:media", "northeastern:drs:repository:staff"]}, "ImageMasterFile" => {"edit" => ["northeastern:drs:college_of_professional_studies:media", "northeastern:drs:repository:staff"]}}

    process_create(permissions, t('loaders.cps.short_name'), "CpsLoadsController", false, true)
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.cps_loader?
    end
end
