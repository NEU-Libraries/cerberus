class WorksController < ActionController::Base
  def new
  end

  def create
    upload = params[:file]
    upload_path = Rails.root.join('tmp', "#{SecureRandom.urlsafe_base64}#{File.extname(upload.original_filename)}")
    File.open(upload_path, 'wb') do |file|
      file.write(upload.read)
    end
  end
end
