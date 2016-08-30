class Loaders::AaiaLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    parent = "neu:cj82n322h"
    process_new(parent, t('loaders.aaia.short_name'))
  end

  def create
    permissions = {"CoreFile" => {"edit" => ["northeastern:drs:jdoaai:archive_staff", "northeastern:drs:repository:staff"]}, "ImageSmallFile" => {"edit" => ["northeastern:drs:jdoaai:archive_staff", "northeastern:drs:repository:staff"]}, "ImageLargeFile" => {"edit" => ["northeastern:drs:jdoaai:archive_staff", "northeastern:drs:repository:staff"]}, "ImageMasterFile" => {"edit" => ["northeastern:drs:jdoaai:archive_staff", "northeastern:drs:repository:staff"]}}

    process_create(permissions, t('loaders.aaia.short_name'), "AaiaLoadsController", false, false)
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.aaia_loader?
    end
end
