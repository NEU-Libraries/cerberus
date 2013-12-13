class MetadataUpdateJob
  include Hydra::PermissionsQuery
  include Rails.application.routes.url_helpers 

  def queue_name
    :metadata_update
  end

  attr_accessor :login, :title, :nu_title, :file_attributes, :visibility

  def initialize(login, params)
    self.login = login
    self.title = params[:title] 
    self.nu_title = params[:title] 
    self.file_attributes = params[:nu_core_file]
    self.visibility = params[:visibility]
  end

  def run

    user = User.find_by_nuid(self.login)
    @saved = []
    @denied = []

    NuCoreFile.users_in_progress_files(user).each do |gf|
      update_file(gf, user)
    end
    
    job_user = User.batchuser()
    
    message = 'The file(s) '+ file_list(@saved)+ " have been saved." unless @saved.empty?
    job_user.send_message(user, message, 'Metadata upload complete') unless @saved.empty?
 
    message = 'The file(s) '+ file_list(@denied)+" could not be updated.  You do not have sufficient privileges to edit it." unless @denied.empty?
    job_user.send_message(user, message, 'Metadata upload permission denied') unless @denied.empty?   
  end

  def update_file(gf, user)
    unless user.can? :edit, gf
      logger.error "User #{user.user_key} DENIED access to #{gf.pid}!"
      @denied << gf
      return
    end

    gf.title = title[gf.pid] if title[gf.pid] rescue gf.label
    gf.nu_title = nu_title[gf.pid] if nu_title[gf.pid] rescue gf.label  
    gf.attributes=file_attributes
    gf.set_visibility(visibility)
    gf.tag_as_completed

    # If this core record is being uploaded into a 'best bits' bucket, 
    # we want to add an UploadAlert entry for the sake of the daily metadata
    # emailing.  Note that all of the actual significant content type metadata
    # is applied during the file upload process. 
    upload_type = gf.parent.personal_folder_type  

    save_tries = 0
    begin
      gf.save!
      if upload_type && !(upload_type == 'user root') 
        ua = UploadAlert.new
        ua.depositor_email = user.email 
        ua.depositor_name  = user.full_name 
        ua.title           = gf.title 
        ua.type            = upload_type 
        ua.pid             = gf.pid 
        ua.save! 
      end
    rescue RSolr::Error::Http => error
      save_tries += 1
      logger.warn "MetadataUpdateJob caught RSOLR error on #{gf.pid}: #{error.inspect}"
      # fail for good if the tries is greater than 3
      raise error if save_tries >=3
      sleep 0.01
      retry
    end #
    Sufia.queue.push(ContentUpdateEventJob.new(gf.pid, login))
    @saved << gf
  end
  
  def file_list (files)
    return files.map {|gf| '<a href="'+nu_core_files_path+'/'+gf.noid+'">'+gf.to_s+'</a>'}.join(', ')   
  end
  
end
