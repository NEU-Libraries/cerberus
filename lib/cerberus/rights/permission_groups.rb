module Cerberus::Rights::PermissionGroups
  RESERVED_GROUPS = ["public",
                     "northeastern:drs:repository:staff",
                     "northeastern:drs:repository:proxystaff"]

  def permission_groups
    self.permissions.keep_if do |x|
      is_group     = x[:type] == 'group'
      not_reserved = !(RESERVED_GROUPS.include? x[:name])
      not_blank    = x[:name].present?
      is_group && not_reserved && not_blank
    end
  end
end
