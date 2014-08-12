module Drs::Rights::PermissionGroups
  RESERVED_GROUPS = ["public",
                     "northeastern:drs:repository:staff",
                     "northeastern:drs:repository:proxystaff"]

  def permission_groups
    self.permissions.keep_if do |x|
      x[:type] == 'group' && !(RESERVED_GROUPS.include? x[:name])
    end
  end
end
