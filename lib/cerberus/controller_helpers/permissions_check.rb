module Cerberus
  module ControllerHelpers
    module PermissionsCheck
      def valid_form_permissions?

        record = controller_name.classify.constantize.find(params[:id])

        valid_permissions = true

        # screen permissions for correct groups...
        existing_groups = record.rightsMetadata.groups.keys - ["public"]
        user_groups = current_user.groups

        valid_groups = existing_groups.concat(user_groups)

        form_groups = params[record.class.name.underscore.to_sym]["permissions"]["identity"]
        permission_vals = params[record.class.name.underscore.to_sym]["permissions"]["permission_type"]

        form_groups.each do |group|
          if !valid_groups.include?(group)
            valid_permissions = false
          end
        end

        permission_vals.each do |perm|
          if !["read","edit"].include?(perm)
            valid_permissions = false
          end
        end

        if !valid_permissions
          raise Exceptions::GroupPermissionsError.new(permission_vals, valid_groups, form_groups, current_user.name)
        end
        return valid_permissions
      end
    end
  end
end
