module Drs
  module ControllerHelpers
    module EditableObjects

      EDITABLE_OBJECTS = [::NuCoreFile, NuCollection, Compilation, Department]

      def can_edit_parent?

        parent_id = find_parent(params)
        department_parent_id = find_department_parent(params)

        if parent_id.nil?
          parent_id = department_parent_id
        end

        if parent_id.nil?          
          raise Exceptions::NoParentFoundError 
        end

        parent_object = lookup(parent_id)

        if current_user.nil?
          render_403 
        elsif current_user.can? :edit, parent_object
          return true
        else
          render_403
        end
      end

      def can_edit_department_parent?

        department_parent_id = find_department_parent(params)

        if department_parent_id.nil?
          raise Exceptions::NoDepartmentParentFoundError 
        end

        department_parent_object = lookup(department_parent_id) 

        if current_user.nil?
          render_403 
        elsif current_user.can? :edit, department_parent_object
          return true
        else
          render_403
        end
      end      

      def can_read? 
        record = lookup(params[:id])  

        if current_user.nil? 
          record.mass_permissions == 'public' ? true : render_403
        elsif current_user.can? :read, record 
          return true 
        else
          render_403
        end
      end

      def can_edit?
        record = lookup(params[:id]) 

        if current_user.nil? 
          render_403
        elsif current_user.can? :edit, record 
          return true
        else
          render_403 
        end
      end

      private
      
        def find_parent(hash) 
          hash.each do |k, v| 
            if k == 'parent' || k == :parent 
              return v
              exit
            elsif v.is_a? Hash 
              return find_parent(v) 
            end
          end
          return nil 
        end

        def find_department_parent(hash) 
          hash.each do |k, v| 
            if k == 'department_parent' || k == :department_parent 
              return v
              exit
            elsif v.is_a? Hash 
              return find_department_parent(v) 
            end
          end
          return nil 
        end

        def lookup(id) 
          if !ActiveFedora::Base.exists?(id) 
            raise Exceptions::IdNotFoundError.new(id) 
          else
            ActiveFedora::Base.find(id, cast: true) 
          end
        end
        
    end
  end
end