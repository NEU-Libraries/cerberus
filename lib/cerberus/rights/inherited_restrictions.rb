# For files with a defined 'parent' relationship

module Cerberus
  module Rights
    module InheritedRestrictions

      def valid_mass_permissions
        if has_parent? 
          return ['private'] if self.parent.mass_permissions == 'private'
        end

        return ['public', 'private'] 
      end

      private

        def has_parent?
          if self.respond_to?(:parent) 
            return self.parent.kind_of?(ActiveFedora::Base) 
          else
            return false 
          end
        end
    end
  end
end