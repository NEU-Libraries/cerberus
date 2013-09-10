class NuCoreFile < ActiveFedora::Base
  include Sufia::GenericFile
  include Drs::MetadataAssignment

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream
  has_metadata name: 'properties', type: DrsPropertiesDatastream
  has_metadata name: 'mods', type: NuModsDatastream

  belongs_to :parent, :property => :is_member_of, :class_name => 'NuCollection'

  def self.create_metadata(nu_core_file, user, collection_id)
    nu_core_file.apply_depositor_metadata(user.user_key)
    nu_core_file.tag_as_in_progress 
    nu_core_file.date_uploaded = Date.today
    nu_core_file.date_modified = Date.today
    nu_core_file.creator = user.name

    if !collection_id.blank?
      nu_core_file.set_parent(NuCollection.find(collection_id), user)
    else
      logger.warn "unable to find collection to attach to"
    end

    yield(nu_core_file) if block_given?
    nu_core_file.save!
  end

  # Safely set the parent of a collection.
  def set_parent(collection, user) 
    if user.can? :edit, collection 
      self.parent = collection
      return true  
    else 
      raise "User with nuid #{user.email} cannot add items to collection with pid of #{collection.pid}" 
    end
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

