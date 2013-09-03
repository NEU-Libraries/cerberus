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
    user = User.find_by_user_key(self.login)
    @saved = []
    @denied = []

    NuCoreFile.users_in_progress_files(user).each do |gf|
      puts "Updating files"
      puts gf.title
      update_file(gf, user)
    end

    puts "Metadata Job finished."
    
    job_user = User.batchuser()
    
    message = '<a class="batchid ui-helper-hidden">ss-'+batch.noid+'</a>The file(s) '+ file_list(@saved)+ " have been saved." unless @saved.empty?
    job_user.send_message(user, message, 'Batch upload complete') unless @saved.empty?
 
    message = '<a class="batchid ui-helper-hidden">'+batch.noid+'</a>The file(s) '+ file_list(@denied)+" could not be updated.  You do not have sufficient privileges to edit it." unless @denied.empty?
    job_user.send_message(user, message, 'Batch upload permission denied') unless @denied.empty?   
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

    save_tries = 0
    begin
      gf.save!
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
