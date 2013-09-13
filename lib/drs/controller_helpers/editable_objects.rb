module Drs
  module ControllerHelpers
    module EditableObjects

      EDITABLE_OBJECTS = [NuCoreFile, NuCollection, Compilation]

      def can_edit_parent?
        parent_object = assign_to_model(ActiveFedora::Base.find(params[:parent]), params[:id])

        if current_user.nil?
          render_403 
        elsif parent_object.nil?
          raise "Passed a pid not pointing at a parent object" 
        elsif current_user.can? :edit, parent_object
          return true
        else
          render_403
        end
      end

      def can_read? 
        record = assign_to_model(ActiveFedora::Base.find(params[:id]), params[:id]) 

        if current_user.nil?
          public_can_read? record
        elsif current_user.can? :read, record 
          return true 
        else
          render_403
        end
      end

      def can_edit?
        record = assign_to_model(ActiveFedora::Base.find(params[:id]), params[:id]) 

        if current_user.nil? 
          render_403
        elsif current_user.can? :edit, record 
          return true
        else
          render_403 
        end
      end

      private

        def assign_to_model(base_object, id)
          model_name = classname_from_fedora(base_object)
          type_match(model_name, id)
        end

        def type_match(string, id)
          editable_strings = EDITABLE_OBJECTS.map { |obj| obj.to_s } 

          if editable_strings.include?(string) 
            return string.constantize.find(id) 
          else
            raise "Attempting to lookup an invalid record.  Aborting." 
          end
        end

        def classname_from_fedora(base_object) 
          whole = base_object.relationships(:has_model).first 

          return whole.split("afmodel:").last
        end

        def public_can_read?(record) 
          record.permissions.each do |perm| 
            is_group = perm[:type] == 'group' 
            is_public = perm[:name] == 'public' 
            is_read = perm[:access] == 'read' 

            if is_group && is_public && is_read
              return true
            end 
          end
          render_403
        end
    end
  end
end