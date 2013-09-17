module Drs
  module ControllerHelpers
    module EditableObjects

      EDITABLE_OBJECTS = [::NuCoreFile, NuCollection, Compilation]

      def can_edit_parent?

        parent_id = find_parent(params)

        if parent_id.nil?
          raise NoParentFoundError 
        end

        parent_object = assign_to_model(parent_id)

        if current_user.nil?
          render_403 
        elsif current_user.can? :edit, parent_object
          return true
        else
          render_403
        end
      end

      def can_read? 
        record = assign_to_model(params[:id]) 

        if current_user.nil?
          public_can_read? record
        elsif current_user.can? :read, record 
          return true 
        else
          render_403
        end
      end

      def can_edit?
        record = assign_to_model(params[:id]) 

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

        def assign_to_model(id)
          if !ActiveFedora::Base.exists?(id) 
            raise IdNotFoundError.new(id) 
          end
          base_object = ActiveFedora::Base.find(id)
          model_name = classname_from_fedora(base_object)
          type_match(model_name, id)
        end

        def type_match(string, id)
          editable_strings = EDITABLE_OBJECTS.map { |obj| obj.to_s } 

          if editable_strings.include?(string) 
            return string.constantize.find(id) 
          else
            raise NoParentFoundError 
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

        class NoParentFoundError < StandardError 
          def initialize
            super "No parent set" 
          end
        end

        class IdNotFoundError < StandardError 
          def initialize(id) 
            super "No item could be found in Fedora with id: #{id}" 
          end
        end
    end
  end
end