module Drs
  module ControllerHelpers
    module SolrEscapeGroups
      def apply_role_permissions(permission_types)
          # for roles
          user_access_filters = []
          current_ability.user_groups.each_with_index do |role, i|
            permission_types.each do |type|
              user_access_filters << escape_filter(ActiveFedora::SolrService.solr_name("#{type}_access_group", Hydra::Datastream::RightsMetadata.indexer), "\"" + role + "\"")
            end
          end
          user_access_filters
      end
    end
  end
end
