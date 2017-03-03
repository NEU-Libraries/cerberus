class Works::WorksController < CatalogController
  include Blacklight::Configurable
  include Blacklight::SearchHelper
  include Blacklight::TokenBasedUser
  include ModsDisplay::ControllerExtension

  copy_blacklight_config_from(CatalogController)

  def new
  end

  def create
    upload = params[:files].first

    upload_path = Rails.root.join('tmp', "#{SecureRandom.urlsafe_base64}#{File.extname(upload.original_filename)}")
    File.open(upload_path, 'wb') do |file|
      file.write(upload.read)
    end

    work = Works::Work.create
    file_set = Hydra::Works::FileSet.create

    file = File.new(upload_path)

    Hydra::Works::UploadFileToFileSet.call(file_set, file)
    file_set.save!

    work.members << file_set
    # temporarily setting to public for now, for dev purposes
    work.permissions_attributes = [{ name: "public", access: "read", type: "group" }]
    work.save!

    # file_set.create_derivatives
    GenerateDerivativesJob.perform_later(file_set.id)
  end

  def show
    @work = Works::Work.find(params[:id])
    @mods = render_mods_display(@work).to_html.html_safe
  end
end
