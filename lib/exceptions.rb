module Exceptions

  class GroupPermissionsError < StandardError
    attr_accessor :valid_groups, :supplied_groups, :user_name
    def initialize(valid_groups, supplied_groups, user_name)
      super("It appears someone has tried to manually change/insert groups into the metadata form. Valid groups are #{valid_groups}, user supplied groups are #{supplied_groups}. The offending user was #{user_name}")
    end
  end

  class NoSuchNuidError < StandardError
    attr_accessor :nuid
    def initialize(nuid)
      self.nuid = nuid
      super("No Employee object with nuid #{self.nuid} could be found in the graph.")
    end
  end

  class MultipleMatchError < StandardError
    attr_accessor :arry, :nuid
    def initialize(array_of_pids, nuid)
      self.arry = array_of_pids
      self.nuid = nuid
      super("The following Employees all have nuid = #{self.nuid} (that's bad): #{arry}")
    end
  end

  class EmployeeWontStopBuildingError < StandardError
    attr_accessor :nuid
    def initialize(nuid)
      self.nuid = nuid
      super("Employee object with nuid #{self.nuid} seems to be stuck in progress.")
    end
  end

  class SearchResultTypeError < StandardError
    def initialize(pid, objClass, superClass)
      super "Expected pid of #{pid} to return type #{superClass} but got #{objClass}"
    end
  end

  class DatastreamNotFoundError < StandardError
    attr_accessor :ds_name, :ds_classname, :object_classname

    def initialize(ds_name, ds_class, calling_object)
      self.ds_name = ds_name
      self.ds_classname = ds_class.to_s
      self.object_classname = calling_object.class.to_s

      super("Datastream with name #{ds_name} of class #{ds_classname} not defined for objects of type #{object_classname}.")
    end
  end

  class ParentMismatchError < StandardError
    def initialize(parent, klass)
      super "Expected parent to be an instance of #{klass}, but it was an instance of #{parent.class}"
    end
  end

  class NoParentFoundError < StandardError
    def initialize
      super "No parent set"
    end
  end

  class NoCommunityParentFoundError < StandardError
    def initialize
      super "No community parent set"
    end
  end

  class AccessNameMismatchError < StandardError
    attr_accessor :access_l, :names_l

    def initialize(access_length, names_length)
      self.access_l = access_length
      self.names_l  = names_length

      super "GroupPermissionsSetter object attempted to run permissions set with #{access_l} access permissions specified and #{names_l} group names specified.  Mismatch not allowed"
    end
  end
end
