# Assumes the existence of a rightsMetadata datastream

module Drs
  module Rights
    module MassPermissions
      extend ActiveSupport::Concern

      included do
        attr_accessible :mass_permissions

        def mass_permissions=(value) 
          if value == 'public' 
            self.rightsMetadata.permissions({group: 'registered'}, 'none') 
            self.rightsMetadata.permissions({group: 'public'}, 'read') 
          elsif value == 'registered'
            self.rightsMetadata.permissions({group: 'public'}, 'none')  
            self.rightsMetadata.permissions({group: 'registered'}, 'read') 
          elsif value == 'private' 
            self.rightsMetadata.permissions({group: 'public'}, 'none') 
            self.rightsMetadata.permissions({group: 'registered'}, 'none') 
          end
        end

        def mass_permissions
          if self.rightsMetadata.permissions({group: 'public'}) == 'read' 
            return 'public' 
          elsif self.rightsMetadata.permissions({group: 'registered'}) == 'read' 
            return 'registered' 
          else 
            return 'private' 
          end
        end
      end
    end
  end
end