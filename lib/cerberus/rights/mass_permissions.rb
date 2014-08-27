# Assumes the existence of a rightsMetadata datastream

module Cerberus
  module Rights
    module MassPermissions
      extend ActiveSupport::Concern

      included do
        attr_accessible :mass_permissions

        def mass_permissions=(value)
          if value == 'public'
            self.rightsMetadata.permissions({group: 'public'}, 'read')
          elsif value == 'private'
            self.rightsMetadata.permissions({group: 'public'}, 'none')
          end
        end

        def mass_permissions
          if self.rightsMetadata.permissions({group: 'public'}) == 'read'
            return 'public'
          else
            return 'private'
          end
        end
      end
    end
  end
end
