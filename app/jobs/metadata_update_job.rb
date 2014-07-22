class MetadataUpdateJob
  include Hydra::PermissionsQuery
  include Rails.application.routes.url_helpers

  def queue_name
    :metadata_update
  end

  attr_accessor :login, :title, :nu_title, :file_attributes

  def initialize(login, params)
    self.login = login
    self.title = params[:title]
    self.nu_title = params[:title]
    self.file_attributes = params[:nu_core_file]
  end

  def run

    employee = Employee.find_by_nuid(self.login)
    @saved = []
    @denied = []

    NuCoreFile.employees_in_progress_files(employee).each do |gf|
      update_file(gf, employee)
    end

    # Still a little kludgey...
    job_user = User.find_by_nuid('000000001') || User.create(password: Devise.friendly_token[0,20], full_name:"Batch User", nuid:"000000001")

    message = 'The file(s) '+ file_list(@saved)+ " have been saved." unless @saved.empty?

    if User.exists_by_nuid?(login)
      actual_user = User.find_by_nuid(login)
      job_user.send_message(actual_user, message, 'Metadata upload complete') unless @saved.empty?

      message = 'The file(s) '+ file_list(@denied)+" could not be updated.  You do not have sufficient privileges to edit it." unless @denied.empty?
      job_user.send_message(actual_user, message, 'Metadata upload permission denied') unless @denied.empty?
    end
  end

  def update_file(gf, user)
    gf.title = title[gf.pid] if title[gf.pid] rescue gf.label
    gf.nu_title = nu_title[gf.pid] if nu_title[gf.pid] rescue gf.label
    gf.attributes=file_attributes
    gf.tag_as_completed
    save_tries = 0

    begin
      gf.save!
      # If this core record is being uploaded into a 'best bits' bucket,
      # we want to add an UploadAlert entry for the sake of the daily metadata
      # emailing.  Note that all of the actual significant content type metadata
      # is applied before this is reached.
      if !gf.category.first.blank?
        #UploadAlert.create_from_core_file(gf, :create)
      end
    rescue RSolr::Error::Http => error
      save_tries += 1
      logger.warn "MetadataUpdateJob caught RSOLR error on #{gf.pid}: #{error.inspect}"
      # fail for good if the tries is greater than 3
      raise error if save_tries >=3
      sleep 0.01
      retry
    end #
    Drs::Application::Queue.push(ContentUpdateEventJob.new(gf.pid, login))
    @saved << gf
  end

  def file_list (files)
    return files.map {|gf| '<a href="'+nu_core_files_path+'/'+gf.pid+'">'+gf.to_s+'</a>'}.join(', ')
  end

end
