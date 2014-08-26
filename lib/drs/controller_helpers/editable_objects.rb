module Drs
  module ControllerHelpers
    module EditableObjects

      EDITABLE_OBJECTS = [::NuCoreFile, Collection, Compilation, Community]

      def deny_to_visitors
        if current_user.nil?
          render_403
        elsif !current_user.admin?
          flash[:notice] = "Admin path denied, your role is #{current_user.role}"
          redirect_to root_path
        end
      end

      def can_edit_parent?
        begin
          parent_object = find_parent(params)

          if current_user.nil?
            render_403
          elsif current_user.can? :edit, parent_object
            return true
          else
            render_403
          end
        rescue ActiveFedora::ObjectNotFoundError
          raise Exceptions::NoParentFoundError
        end
      end

      # Checks if the current user can read the fedora record
      # returned by a typical resource request.
      def can_read?
        begin
          record = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first)
        rescue NoMethodError
          render_404(ActiveFedora::ObjectNotFoundError.new) and return
        end

        if current_user.nil?
          record.public? ? true : render_403
        elsif current_user.can? :read, record
          return true
        else
          render_403
        end
      end

      # Same thing as above but with editing.
      def can_edit?
        begin
          record = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first)
        rescue NoMethodError
          render_404(ActiveFedora::ObjectNotFoundError.new) and return
        end

        if current_user.nil?
          render_403
        elsif !record.smart_collection_type.nil? && record.smart_collection_type != "miscellany"
          render_403
        elsif current_user.can? :edit, record
          return true
        else
          render_403
        end
      end

      def is_depositor?
        record = ActiveFedora::Base.find(params[:id], cast: true)

        if !current_user.nil? && current_user.nuid == record.depositor
          return true
        else
          render_403
        end
      end

      private

        def find_parent(hash)
          hash.each do |k, v|
            if k == 'parent' || k == :parent
              # return ActiveFedora::Base.find(v, cast: true)
              # exit
              begin
                return SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{v}\"").first)
              rescue NoMethodError
                raise Exceptions::NoParentFoundError
              end
            elsif v.is_a? Hash
              return find_parent(v)
            end
          end
          raise Exceptions::NoParentFoundError
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
    end
  end
end
