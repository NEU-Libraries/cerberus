class NuCollection < ActiveFedora::Base
  include Hydra::ModelMethods
  include Hydra::ModelMixins::CommonMetadata  
  include Hydra::ModelMixins::RightsMetadata
  include ActiveModel::MassAssignmentSecurity
  include ModsSetterHelpers

  attr_accessible :title, :description, :date_of_issue, :keywords, :parent, :mass_permissions 
  attr_accessible :corporate_creators, :personal_creators, :embargo_release_date

  attr_protected :identifier 

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream 
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'properties', type: DrsPropertiesDatastream
  has_metadata name: 'mods', type: NuModsDatastream
  has_metadata name: 'crud', type: CrudDatastream

  delegate_to :DC, [:nu_title, :nu_description, :nu_identifier]
  # delegate_to :mods, [:mods_title, :mods_abstract, :mods_identifier, :mods_subject, :mods_date_issued] 
  delegate_to :properties, [:depositor]  

  has_many :child_files, property: :is_member_of, :class_name => "NuCoreFile"
  has_many :child_collections, property: :is_member_of, :class_name => "NuCollection"
  belongs_to :parent, property: :is_member_of, :class_name => "NuCollection" 

  # Return all collections that this user can read
  def self.find_all_viewable(user) 
    collections = NuCollection.find(:all)
    filtered = collections.select { |ele| !ele.embargo_in_effect?(user) && ele.rightsMetadata.can_read?(user) }
    return filtered 
  end

  # Override parent= so that the string passed by the creation form can be used. 
  def parent=(collection_id)
    if collection_id.instance_of?(String) 
      self.add_relationship(:is_member_of, NuCollection.find(collection_id))
    elsif collection_id.instance_of?(NuCollection)
      self.add_relationship(:is_member_of, collection_id) 
    else
      raise "parent= got passed a #{collection_id.class}, which doesn't work."
    end
  end

  def depositor 
    return self.properties.depositor.first 
  end

  def parent
    if self.relationships(:is_member_of).any?
      NuCollection.find(self.relationships(:is_member_of).first.partition('/').last)
    else
      nil
    end
  end

  def title=(string)
    self.mods_title = string
    self.nu_title = string 
  end

  def title
    self.mods_title 
  end

  def identifier=(string)
    self.nu_identifier = string 
    self.mods_identifier = string 
  end

  def identifier
    self.mods_identifier 
  end

  def description=(string)
    self.nu_description = string 
    self.mods_abstract = string 
  end

  def description 
    self.mods_abstract 
  end

  def date_of_issue=(string) 
    self.mods_date_issued = string 
  end

  def date_of_issue
    self.mods_date_issued 
  end

  def keywords=(array_of_strings) 
    self.mods_keyword = array_of_strings 
  end

  def keywords 
    self.mods_keyword 
  end

  def corporate_creators=(array_of_strings) 
    self.mods_corporate_creators = array_of_strings
  end

  def corporate_creators
    self.mods_corporate_creators 
  end

  def personal_creators=(hash)
    first_names = hash['creator_first_names'] 
    last_names = hash['creator_last_names']  

    self.set_mods_personal_creators(first_names, last_names) 
  end

  def personal_creators 
    self.mods_personal_creators 
  end

  def embargo_release_date=(string) 
    self.rightsMetadata.embargo_release_date = string
  end

  def embargo_release_date 
    rightsMetadata.embargo_release_date 
  end

  def permissions=(hash)
    self.set_permissions_from_new_form(hash) 
  end

  # Might need to be broken into a RightsMetadata module 
  def mass_permissions=(value) 
    if value == 'public' 
      self.rightsMetadata.permissions({group: 'registered'}, 'none') 
      self.rightsMetadata.permissions({group: 'public'}, 'read') 
    elsif value == 'registered'
      self.rightsMetadata.permissions({group: 'public'}, 'none')  
      self.rightsMetadata.permissions({group: 'registered'}, 'read') 
    elsif value == 'private' 
      self.rightsMetadata.permissions({group: 'public'}, 'none') 
      self.rightsMetadata.permissions({group: 'registered'}, 'none') 
    end
  end

  def mass_permissions
    if self.rightsMetadata.permissions({group: 'public'}) == 'read' 
      return 'public' 
    elsif self.rightsMetadata.permissions({group: 'registered'}) == 'read' 
      return 'registered' 
    else 
      return 'private' 
    end
  end

  # Since we need access to the depositor metadata field, we handle this
  # at this level. 
  def embargo_in_effect?(user)
    if user.nil?
      return self.rightsMetadata.under_embargo?
    else
      return self.rightsMetadata.under_embargo? && !(self.depositor == user.nuid)
    end
  end

  # Accepts a hash of the following form:
  # ex. {'permissions1' => {'identity_type' => val, 'identity' => val, 'permission_type' => val }, 'permissions2' => etc. etc. }
  # Tosses out param sets that are missing an identity.  Which is nice.   
  def set_permissions_from_new_form(params)
    params.each do |perm_hash| 
      identity_type = perm_hash[1]['identity_type']
      identity = perm_hash[1]['identity']
      permission_type = perm_hash[1]['permission_type'] 

      if identity != 'public' && identity != 'registered' 
        self.rightsMetadata.permissions({identity_type => identity}, permission_type)
      end 
    end
  end
end
