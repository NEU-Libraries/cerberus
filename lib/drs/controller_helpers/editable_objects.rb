module Drs
  module ControllerHelpers
    module EditableObjects

      EDITABLE_OBJECTS = [::NuCoreFile, NuCollection, Compilation, Community]

      def can_edit_parent?

        parent_id = find_parent(params)

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

      # Checks if the current user can read the fedora record 
      # returned by a typical resource request.  
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

      # Same thing as above but with editing.
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

        def find_community_parent(hash)
          hash.symbolize!

          hash.each do |k, v| 
            if k == 'community_parent' || k == :community_parent 
              return v
              exit
            elsif v.is_a? Hash 
              return find_community_parent(v) 
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