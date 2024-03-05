class StaticController < ApplicationController
  include Cerberus::TempFileStorage
  include ZipHelper
  rescue_from AbstractController::ActionNotFound, with: :render_404

  def mods_download
    send_file "#{Rails.application.config.tmp_path}/mods/#{params[:session_id]}-#{params[:id].split(":").last}/mods_export.zip"
  end

  def manifest_download
    send_file "#{Rails.application.config.tmp_path}/manifest/#{params[:session_id]}-#{params[:id].split(":").last}/manifest_export.zip"
  end

  def large_download
    send_file "#{Rails.application.config.tmp_path}/large/#{params[:session_id]}/#{params[:time]}.zip"
  end

  def upload
    if !current_user.blank? && (current_user.admin? || current_user.admin_group?)
      # Custom upload form for staging metadata files for DPS async image loading from AWS
      # Need to provide form with dir list - done
      # Need to restrict access - done
      # Need to create and/or purge box dir - done
      # @boxes = Dir.entries("/mnt/libraries/Boston-Globe/").reject {|x| x == "." || x == ".."}
      #  => becomes ["1015935951", "1015936049", etc.]

      @boxes = Dir.entries("/mnt/libraries/Boston-Globe/").reject {|x| x == "." || x == ".."}
    else
      render_403 and return
    end
  end

  def process_staged_upload
    if !current_user.blank? && (current_user.admin? || current_user.admin_group?)
      new_path = move_file_to_tmp(params[:file])
      dir_path = "/mnt/libraries/Boston-Globe/" + params[:box_number]

      # if exists - wipe
      if File.exists? dir_path
        FileUtils.rm_rf(Dir.glob("#{dir_path}/*")) if File.directory?(dir_path)
      else
        # make it
        FileUtils.mkdir(dir_path)
      end

      file_list = safe_unzip(new_path, dir_path)
      flash[:notice] = "Zip file updated."
      redirect_to root_path and return
    else
      render_403 and return
    end
  end
end
