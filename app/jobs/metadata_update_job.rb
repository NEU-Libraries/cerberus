class MetadataUpdateJob
  include Hydra::PermissionsQuery
  include Rails.application.routes.url_helpers

  def queue_name
    :metadata_update
  end

  attr_accessor :depositor_nuid, :title, :nu_title, :file_attributes, :uploader_nuid

  def initialize(nuid, params, proxier_nuid=nil)
    self.depositor_nuid = nuid
    self.title = params[:title]
    self.nu_title = params[:title]
    self.file_attributes = params[:nu_core_file]
    self.uploader_nuid = proxier_nuid
  end

  def run
    @saved = []
    @denied = []

    NuCoreFile.in_progress_files_for_nuid(depositor_nuid).each do |gf|
      update_file(gf)
    end

    # Still a little kludgey...
    msgd = (uploader_nuid ? User.find_by_nuid(uploader_nuid) : User.find_by_nuid(depositor_nuid))
    job_user = User.find_by_nuid('000000001') || User.create(password: Devise.friendly_token[0,20], full_name:"Batch User", nuid:"000000001")

    message = 'The file(s) '+ file_list(@saved)+ " have been saved." unless @saved.empty?
    job_user.send_message(msgd, message, 'Metadata upload complete') unless @saved.empty?

    message = 'The file(s) '+ file_list(@denied)+" could not be updated.  You do not have sufficient privileges to edit it." unless @denied.empty?
    job_user.send_message(msgd, message, 'Metadata upload permission denied') unless @denied.empty?
  end

  def update_file(gf)
    gf.title = title[gf.pid] if title[gf.pid] rescue gf.label
    gf.nu_title = nu_title[gf.pid] if nu_title[gf.pid] rescue gf.label
    gf.attributes=file_attributes
    save_tries = 0

    begin
      gf.save!
      # If this core record is being uploaded into a 'best bits' bucket,
      # we want to add an UploadAlert entry for the sake of the daily metadata
      # emailing.  Note that all of the actual significant content type metadata
      # is applied before this is reached.
      if !gf.category.first.blank?
        UploadAlert.create_from_core_file(gf, :create)
      end
    rescue RSolr::Error::Http => error
      save_tries += 1
      logger.warn "MetadataUpdateJob caught RSOLR error on #{gf.pid}: #{error.inspect}"
      # fail for good if the tries is greater than 3
      raise error if save_tries >=3
      sleep 0.01
      retry
    end #
    Drs::Application::Queue.push(ContentUpdateEventJob.new(gf.pid, gf.true_depositor))
    @saved << gf
  end

  def file_list (files)
    return files.map {|gf| '<a href="'+nu_core_files_path+'/'+gf.pid+'">'+gf.to_s+'</a>'}.join(', ')
  end

end
