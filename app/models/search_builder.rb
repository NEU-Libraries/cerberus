# frozen_string_literal: true

class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior

  self.default_processor_chain += [:apply_gated_discovery, :append_extra_filters]

  def apply_gated_discovery(solr_parameters)
    # Admins carry the `can :manage, :all` short-circuit in Ability, but that
    # only governs CanCanCan checks on documents already in hand — it never
    # touches the Solr query. Mirror the short-circuit at the discovery layer
    # so an admin (who may belong to no groups) actually *sees* every resource
    # in search, not just public ones. Without this, admin-only surfaces that
    # need to find non-public containers (e.g. the re-parent finder) silently
    # return only public hits.
    return if current_user&.admin?

    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "{!terms f=read_access_group_ssim}#{discovery_permissions.join(',')}"
  end

  # Register additional fq fragments to AND onto this query.
  #
  # Use this instead of `.merge(fq: [...])`: Blacklight's `#to_hash` finishes with
  # `processed_parameters.merge(@merged_params)`, so a merged `:fq` *replaces* the
  # whole fq array — silently discarding the `apply_gated_discovery` clause the
  # processor chain just appended (i.e. the query stops being access-gated). These
  # filters are applied inside the chain (see {#append_extra_filters}) so they
  # coexist with gated discovery.
  #
  # @param filters [Array<String>] fq fragments (e.g. from {MembershipQuery}).
  # @return [self]
  def with_filters(*filters)
    @extra_filters = filters.flatten.compact
    params_will_change!
    self
  end

  def append_extra_filters(solr_parameters)
    return if @extra_filters.blank?

    solr_parameters[:fq] ||= []
    solr_parameters[:fq].concat(@extra_filters)
  end

  private

    def current_user
      scope.respond_to?(:current_user) ? scope.current_user : nil
    end

    def discovery_permissions
      permissions = ['public']
      permissions.concat(Array(current_user&.groups))
      permissions.uniq
    end
end
