class StaticController < ApplicationController
  rescue_from AbstractController::ActionNotFound, with: :render_404

  def mods_download
    send_file "#{Rails.application.config.tmp_path}/mods/#{params[:session_id]}-#{params[:id].split(":").last}/mods_export.zip"
  end
end
