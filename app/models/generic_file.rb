class GenericFile < ActiveFedora::Base
  include Sufia::GenericFile
  # This can be found in our gem fork at: 
  # sufia-models/lib/models/generic_file.rb  

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream 

  delegate_to :DC, [:nu_title, :nu_type, :nu_identifier, :nu_description]

  def self.create_metadata(generic_file, user, collection_id)
    generic_file.apply_depositor_metadata(user.user_key)
    generic_file.tag_as_in_progress 
    generic_file.date_uploaded = Date.today
    generic_file.date_modified = Date.today
    generic_file.creator = user.name

    #if batch_id
      #generic_file.add_relationship("isPartOf", "info:fedora/#{Sufia::Noid.namespaceize(batch_id)}")
    #else
      #logger.warn "unable to find batch to attach to"
    #end

    if collection_id
      generic_file.add_relationship("isPartOf", "info:fedora/#{Sufia::Noid.namespaceize(collection_id)}")
    else
      logger.warn "unable to find collection to attach to"
    end

    yield(generic_file) if block_given?
    generic_file.save!
  end

  # Return a list of all in progress files associated with this user
  def self.users_in_progress_files(user)
    all = GenericFile.find(:all) 

    filtered = all.keep_if { |file| file.in_progress_for_user?(user) } 

    return filtered  
  end

  def in_progress_for_user?(user)  
    return self.properties.in_progress?  && user.nuid == self.depositor 
  end

  def tag_as_completed 
    self.properties.tag_as_complete 
  end

  def tag_as_in_progress 
    self.properties.tag_as_in_progress 
  end
end 

