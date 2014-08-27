module Cerberus
  module Rights
    module PermissionsAssignmentHelper  
      # Accepts a hash of the following form:
      # ex. {'permissions1' => {'identity_type' => val, 'identity' => val, 'permission_type' => val }, 'permissions2' => etc. etc. }
      # Tosses out param sets that are missing an identity.  Which is nice.   
      def permissions=(params)
        params.each do |perm_hash| 
          identity_type = perm_hash[1]['identity_type']
          identity = perm_hash[1]['identity']
          permission_type = perm_hash[1]['permission_type'] 

          if identity != 'public' && identity != 'registered' 
            self.rightsMetadata.permissions({identity_type => identity}, permission_type)
          end 
        end
      end
    end
  end
end  