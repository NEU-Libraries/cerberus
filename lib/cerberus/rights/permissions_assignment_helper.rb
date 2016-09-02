module Cerberus
  module Rights
    module PermissionsAssignmentHelper
      def permissions=(params)
        # Coming from the create/edit metadata form...
        if params.has_key?("identity") && params.has_key?("permission_type") && !params.has_key?("identity_type")
          # delete groups excepting mass permissions
          existing_groups = self.rightsMetadata.groups.keys - ["public", "northeastern:drs:repository:staff"]
          form_groups = params["identity"]
          groups_to_delete = existing_groups - form_groups

          groups_to_delete.each do |group|
            self.rightsMetadata.permissions({group: group}, 'none')
          end

          # sort so that edit goes last, being the stronger permission over read
          zipped_groups = params["identity"].zip(params["permission_type"]).delete_if {|x| x[0].blank?}
          sorted_groups = zipped_groups.sort_by{|k,v| v == "read" ? 0 : 1}.uniq

          # add groups
          # form_groups.each_with_index do |group, i|
          sorted_groups.each do |group, edit_perm|
            # check that the end user hasn't tried to surreptitiously edited the form to none
            if group != 'public' && group != 'registered' && !group.blank? && edit_perm != "none"
              self.rightsMetadata.permissions({group: group}, edit_perm)
            end
          end
        else
          # Accepts a hash of the following form:
          # ex. {'permissions1' => {'identity_type' => val, 'identity' => val, 'permission_type' => val }, 'permissions2' => etc. etc. }
          # Tosses out param sets that are missing an identity.  Which is nice.
          params.each do |perm_hash|
            identity_type = perm_hash[1]['identity_type']
            identity = perm_hash[1]['identity']
            permission_type = perm_hash[1]['permission_type']

            if identity != 'public' && identity != 'registered' && permission_type != "none"
              self.rightsMetadata.permissions({identity_type => identity}, permission_type)
            end
          end
        end
      end
    end
  end
end
