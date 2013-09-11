# For files with a defined 'parent' relationship

module Drs
  module Rights
    module InheritedRestrictions
      extend ActiveSupport::Concern
      extend ActiveModel::Callbacks
      include Drs::Rights::MassPermissions
      include Hydra::ModelMixins::RightsMetadata

      def valid_mass_permissions
        if has_parent? 
          a = parents_mass_permissions 

          if a == 'public' 
            return ['public', 'registered', 'private'] 
          elsif a == 'registered' 
            return ['registered', 'private'] 
          elsif a == 'private' 
            return ['private'] 
          end
        end

        return ['public', 'registered', 'private'] 
      end

      private

        def has_parent?
          if self.respond_to?(:parent) 
            return self.parent.kind_of?(ActiveFedora::Base) 
          else
            return false 
          end
        end

        # Returns 'public', 'private', or 'registered' 
        def parents_mass_permissions 
          self.parent.mass_permissions 
        end
    end
  end
end