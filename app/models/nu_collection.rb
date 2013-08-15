class NuCollection < ActiveFedora::Base
  include Hydra::ModelMethods
  include Hydra::ModelMixins::CommonMetadata  
  include Hydra::ModelMixins::RightsMetadata  

  attr_accessor :nu_title, :nu_description

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream 
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'properties', type: PropertiesDatastream
  has_metadata name: 'mods', type: NuModsDatastream
  has_metadata name: 'crud', type: CrudDatastream

  delegate_to :DC, [:nu_title, :nu_description, :nu_identifier]
  delegate_to :mods, [:mods_title, :mods_abstract, :mods_identifier, :mods_subject, :mods_date_issued] 
  delegate_to :properties, [:depositor]  

  has_many :generic_files, property: :is_part_of 
  has_many :nu_collections, property: :is_part_of 

  # Return all collections that this user can read
  def self.find_all_viewable(user) 
    collections = NuCollection.find(:all)
    collections.keep_if { |ele| !ele.embargo_in_effect?(user) && ele.rightsMetadata.can_read?(user) } 
  end

  def nu_title_display 
    self.nu_title.first
  end

  def nu_description_display 
    self.nu_description.first 
  end

  def mods_title_display 
    self.mods_title.first 
  end

  def mods_abstract_display 
    self.mods_abstract.first 
  end

  # Since we need access to the depositor metadata field, we handle this
  # at this level. 
  def embargo_in_effect?(user)
    return self.rightsMetadata.under_embargo? && ! (self.depositor == user.nuid)  
  end

  # The params we get passed aren't quite clean enough to leverage the usual Rails form helpers
  # So we're making Datastreams responsible for knowing how to construct their own MODS metadata
  # from the params passed in on the #new action 
  def create_mods_stream(params)
    # Simple assignments
    self.mods_abstract = params[:nu_collection][:nu_description]
    self.mods_title = [params[:nu_collection][:nu_title]]
    self.mods_identifier = self.id
    self.mods_date_issued = params[:nu_collection][:issuance_date]
    self.mods.mods_keyword = params[:nu_collection][:keyword]
    self.mods.mods_type_of_resource.mods_collection = 'yes' 

    # Complicated or validation required assignments 
    self.mods.assign_creator_personal_names(params[:nu_collection][:creator_first_name], params[:nu_collection][:creator_last_name])
    self.mods.assign_corporate_names(params[:nu_collection][:creator_corporate])
  end


  # Accepts a hash of the following form:
  # ex. {'permissions1' => {'identity_type' => val, 'identity' => val, 'permission_type' => val }, 'permissions2' => etc. etc. }
  # Tosses out param sets that are missing an identity.  Which is nice.   
  def set_permissions_from_new_form(params)
    params.each do |perm_hash| 
      identity_type = perm_hash[1]['identity_type']
      identity = perm_hash[1]['identity']
      permission_type = perm_hash[1]['permission_type'] 

      self.rightsMetadata.permissions({identity_type => identity}, permission_type) 
    end
  end
end
