class NuCoreFile < ActiveFedora::Base
  include Sufia::GenericFile
  # This can be found in our gem fork at: 
  # sufia-models/lib/models/nu_core_file.rb  

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream
  has_metadata name: 'properties', type: DrsPropertiesDatastream

  delegate_to :DC, [:nu_title, :nu_type, :nu_identifier, :nu_description]

  def self.create_metadata(nu_core_file, user, collection_id)
    nu_core_file.apply_depositor_metadata(user.user_key)
    nu_core_file.tag_as_in_progress 
    nu_core_file.date_uploaded = Date.today
    nu_core_file.date_modified = Date.today
    nu_core_file.creator = user.name

    #if batch_id
      #nu_core_file.add_relationship("isPartOf", "info:fedora/#{Sufia::Noid.namespaceize(batch_id)}")
    #else
      #logger.warn "unable to find batch to attach to"
    #end

    if collection_id
      nu_core_file.add_relationship("isPartOf", "info:fedora/#{Sufia::Noid.namespaceize(collection_id)}")
    else
      logger.warn "unable to find collection to attach to"
    end

    yield(nu_core_file) if block_given?
    nu_core_file.save!
  end

  # Return a list of all in progress files associated with this user
  def self.users_in_progress_files(user)
    all = NuCoreFile.find(:all) 
    filtered = all.keep_if { |file| file.in_progress_for_user?(user) } 
    return filtered  
  end

  def in_progress_for_user?(user)
    return self.properties.in_progress? && user.nuid == self.depositor 
  end

  def tag_as_completed 
    self.properties.tag_as_completed 
  end

  def tag_as_in_progress 
    self.properties.tag_as_in_progress 
  end
end 

