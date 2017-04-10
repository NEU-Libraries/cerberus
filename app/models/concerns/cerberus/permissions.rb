module Cerberus::Permissions
  def privatize!
    self.permissions_attributes = [{ name: "public", access: "read", type: "group", _destroy: "true" }]
    self.save!
  end

  def publicize!
    self.permissions_attributes = [{ name: "public", access: "read", type: "group" }]
    self.save!
  end

  def privatize
    self.permissions_attributes = [{ name: "public", access: "read", type: "group", _destroy: "true" }]
  end

  def publicize
    self.permissions_attributes = [{ name: "public", access: "read", type: "group" }]
  end

  def public?
    self.read_groups.include? "public"
  end

  def private?
    !self.read_groups.include? "public"
  end
end
