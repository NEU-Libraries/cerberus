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

    # Grab the user's individual permissions 
    uid = user.nuid 
    rights = self.permissions({person: uid})

    # Grab all groups associated with this user
    user_groups = user.group_list 

    return user_can_read_or_edit?(uid, access_requested) || group_can_read_or_edit?(user_groups, access_requested)
  end

  def user_can_read_or_edit?(uid, access_requested)
    rights = self.permissions({person: uid})

    if access_requested == :read 
      return rights == 'read' || rights == 'edit' 
    elsif access_requested == :edit 
      return rights == 'edit' 
    else
      raise "#{access_requested.to_s} is not a valid access type to request" 
    end
  end

  def group_can_read_or_edit?(user_groups, access_requested) 
    if access_requested == :read 
      group_can_read?(user_groups)
    elsif access_requested == :edit 
      group_can_edit?(user_groups) 
    else
      raise "#{access_requested.to_s} is not a valid access type to request" 
    end
  end

  def group_can_read?(user_groups)
    permitted_groups = self.groups

    if !user_groups  
      return false
    end 

    user_groups.each do |user_group| 
      if permitted_groups.include?(user_group)
        return true
      end
    end

    return false 
  end

  def group_can_edit?(user_groups) 
    permitted_groups = self.groups

    if !user_groups
      return false
    end 

    user_groups.each do |user_group| 
      if permitted_groups.include?(user_group)
        if permitted_groups[user_group] == 'edit'
          return true
        end
      end
    end

    return false 
  end 
end