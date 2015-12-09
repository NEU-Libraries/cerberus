module Exceptions

  class SecurityEscalationError < StandardError
    def initialize
      super "Attempted impersonation of an admin user"
    end
  end

  class GroupPermissionsError < StandardError
    attr_accessor :valid_groups, :supplied_groups, :user_name, :permissions
    def initialize(permissions, valid_groups, supplied_groups, user_name)
      super("It appears someone has tried to manually change the metadata form. Valid groups are #{valid_groups}, user supplied groups are #{supplied_groups}. Permissions supplied were #{permissions}. The offending user was #{user_name}")
    end
  end

  class NoNuidProvided < StandardError
    def initialize
      super "No nuid provided by shib"
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

  class SolrizationError < StandardError
    def initialize
      super "Unable to create solr doc"
    end
  end

  class InvalidMassPermissionsError < StandardError
    def initialize
      super "Invalid mass permissions set"
    end
  end

  class NoMassPermissionsError < StandardError
    def initialize
      super "No mass permissions set"
    end
  end

  class NoCanonicalClassFoundError < StandardError
    def initialize
      super "No canonical class set"
    end
  end

  class NoCanonicalObjectFoundError < StandardError
    def initialize
      super "No canonical object set"
    end
  end

  class NoDepositorFoundError < StandardError
    def initialize
      super "No depositor set"
    end
  end

  class InvalidDepositorPermissionsError < StandardError
    def initialize
      super "The depositor can't edit this object"
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

  class MissingMetadata < StandardError
    def initialize(required_data)
      super "No valid #{required_data} in xml"
    end
  end

  class TombstonedObject < StandardError
    def initialize
      super "This object has been tombstoned"
    end
  end

  class XmlEncodingError < StandardError
    def initialize
      super "This object requires a prolog with UTF-8 encoding."
    end
  end
end
