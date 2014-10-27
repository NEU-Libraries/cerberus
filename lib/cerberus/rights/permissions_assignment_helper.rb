module Cerberus
  module Rights
    module PermissionsAssignmentHelper
      # Accepts a hash of the following form:
      # ex. {'permissions1' => {'identity_type' => val, 'identity' => val, 'permission_type' => val }, 'permissions2' => etc. etc. }
      # Tosses out param sets that are missing an identity.  Which is nice.
      def permissions=(params)
        # Coming from the create/edit metadata form...
        if params.has_key?("identity") && params.has_key?("permission_type") && !params.has_key?("identity_type")
          # delete groups excepting mass permissions
          existing_groups = self.rightsMetadata.groups.keys - ["public"]
          form_groups = params["identity"]
          groups_to_delete = existing_groups - form_groups

          groups_to_delete.each do |group|
            self.rightsMetadata.permissions({group: group}, 'none')
          end

          # add groups
          form_groups.each_with_index do |group, i|
            if group != 'public' && group != 'registered'
              self.rightsMetadata.permissions({group: group}, params["permission_type"][i])
            end
          end
        else
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
end
