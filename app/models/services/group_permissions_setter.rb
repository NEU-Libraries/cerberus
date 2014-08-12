class GroupPermissionsSetter
  attr_accessor :object, :groups

  def initialize(object, group_hash)
    self.object = object
    self.groups  = group_hash
  end

  RESERVED_GROUPS = ["northeastern:drs:repository:staff",
                     "northeastern:drs:repository:proxystaff",
                     "public"]

  def self.set_permissions!(object, params)
    g = GroupPermissionsSetter.new(object, params)
    g.set_permissions!
  end

  def self.set_permissions(object, params)
    g = GroupPermissionsSetter.new(object, params)
    g.set_permissions
  end

  def set_permissions
    groups      = self.groups.with_indifferent_access
    access_type = nil

    if groups["permission_type"]
      access_type = groups["permission_type"]
    end

    # Remove all removed groups
    removed = groups["permissionless_groups"]
    if removed.present?
      removed = removed.split ";"
      removed = removed.map { |x| x.strip }

      removed.each do |name|
        if !(RESERVED_GROUPS.include? name)
          perm  = { name: name, access: "none", type: "group" }
          object.permissions = [perm]
        end
      end
    end

    access = groups["access"] || []
    names  = groups["name"]   || []

    if (names.length != access.length) && !(access_type)
      raise Exceptions::AccessNameMismatchError.new(access.length, names.length)
    end

    names.each_with_index do |name, i|
      if !(RESERVED_GROUPS.include? name) && name.present?
        access_type ||= access[i]
        perm          = {name: name, access: access_type, type: "group"}
        object.permissions = [perm]
      end
    end

    return object
  end

  def set_permissions!
    set_permissions
    object.save!
  end
end
