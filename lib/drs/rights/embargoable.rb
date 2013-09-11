# Include this for content types that should theoretically be embargoable.
# Assumes the existence of a rightsMetadata datastream. 

module Drs
  module Rights
    module Embargoable
      extend ActiveSupport::Concern

      included do 
        attr_accessible :embargo_release_date

        def embargo_release_date=(string) 
          self.rightsMetadata.embargo_release_date = string
        end

        def embargo_release_date 
          self.rightsMetadata.embargo_release_date 
        end

        def embargo_in_effect?(user)
          if user.nil?
            return self.rightsMetadata.under_embargo?
          else
            return self.rightsMetadata.under_embargo? && !(self.depositor == user.nuid)
          end
        end
      end
    end
  end
end
