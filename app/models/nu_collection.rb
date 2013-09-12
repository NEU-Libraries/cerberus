class NuCollection < ActiveFedora::Base 
  include ActiveModel::MassAssignmentSecurity
  include Hydra::ModelMixins::RightsMetadata
  include Drs::Rights::MassPermissions
  include Drs::Rights::Embargoable
  include Drs::Rights::InheritedRestrictions
  include Drs::MetadataAssignment

  attr_accessible :title, :description, :date_of_issue, :keywords, :parent 
  attr_accessible :corporate_creators, :personal_creators

  attr_protected :identifier 

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream 
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'properties', type: DrsPropertiesDatastream
  has_metadata name: 'mods', type: NuModsDatastream 

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

  def permissions=(hash)
    self.set_permissions_from_new_form(hash) 
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
