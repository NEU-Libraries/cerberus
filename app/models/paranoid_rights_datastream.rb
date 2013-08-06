class ParanoidRightsDatastream < Hydra::Datastream::RightsMetadata
  use_terminology Hydra::Datastream::RightsMetadata

  VALIDATIONS = [
    {:key => :edit_users, :message => 'Depositor must have edit access', :condition => lambda { |obj| !obj.edit_users.include?(obj.depositor) }},
    {:key => :edit_groups, :message => 'Public cannot have edit access', :condition => lambda { |obj| obj.edit_groups.include?('public') }},
    {:key => :edit_groups, :message => 'Registered cannot have edit access', :condition => lambda { |obj| obj.edit_groups.include?('registered') }}
  ]

  def validate(object)
    valid = true
    VALIDATIONS.each do |validation|
      if validation[:condition].call(object)
        object.errors[validation[:key]] ||= []
        object.errors[validation[:key]] << validation[:message]
        valid = false
      end
    end
    return valid
  end

  # Checks whether or not a given user can read (view/download) this collection or file
  # TODO:  Add group membership checks when Shibboleth stuff comes in
  def can_read?(user) 
    can_read_or_edit?(user, :read) 
  end

  #Checks whether or not a given user can edit this collection or file
  def can_edit?(user) 
    can_read_or_edit?(user, :edit) 
  end

  protected 

  def can_read_or_edit?(user, access_requested) 
    if !user.instance_of?(User) # Cover the case where current_user passes in nil, indicating unsigned access
      public_rights = self.permissions({group: 'public'}) 
      return public_rights == 'read' && access_requested == :read 
    end

    uid = user.nuid 
    rights = self.permissions({person: uid}) 

    if access_requested == :read 
      return rights == 'read' || rights == 'edit' 
    elsif access_requested == :edit 
      return rights == 'edit' 
    else
      raise "#{access_requested.to_s} is not a valid access type to request" 
    end
  end
end