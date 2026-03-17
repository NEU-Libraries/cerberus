# frozen_string_literal: true

class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior

  self.default_processor_chain += [:apply_gated_discovery]

  def apply_gated_discovery(solr_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "{!terms f=read_access_group_ssim}#{discovery_permissions.join(',')}"
  end

  private

    def discovery_permissions
      permissions = ['public']
      user = scope.respond_to?(:current_user) ? scope.current_user : nil
      permissions.concat(Array(user&.groups))
      permissions.uniq
    end
end
