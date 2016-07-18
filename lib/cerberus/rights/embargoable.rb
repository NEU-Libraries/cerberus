# Include this for content types that should theoretically be embargoable.
# Assumes the existence of a rightsMetadata datastream.

module Cerberus
  module Rights
    module Embargoable
      extend ActiveSupport::Concern

      included do
        attr_accessible :embargo_release_date

        def embargo_release_date=(release_date)
          release_date = release_date.to_s if release_date.is_a? Date
          if !release_date.blank?            
            begin
              Date.parse(release_date)
            rescue
              raise "Invalid embargo release date."
            end
            self.rightsMetadata.update_values({[:embargo,:machine,:date]=>release_date})
          end
        end

        def embargo_release_date
          self.rightsMetadata.embargo_release_date
        end

        def under_embargo?(user)
          if user.nil?
            return self.rightsMetadata.under_embargo?
          else
            is_not_depositor  = !(self.depositor == user.nuid)
            is_not_repo_staff = !(user.repo_staff?)
            return self.rightsMetadata.under_embargo? && is_not_depositor && is_not_repo_staff
          end
        end
      end
    end
  end
end
