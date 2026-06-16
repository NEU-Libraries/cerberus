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
    #
    # Gating keys off the EFFECTIVE user (see {#gated_user}), not the
    # authenticated one — so an admin in a view-as session is gated AS the
    # target, both here and in the group filter below. Keying off the real
    # admin would silently leak every result under a view-as banner.
    return if gated_user&.admin?

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

    # The user discovery is gated AS. Prefer the controller's effective_user
    # (the view-as target during a view-as session; the real user otherwise),
    # falling back to current_user for scopes that predate impersonation
    # (e.g. bare doubles in specs).
    #
    # Blacklight 8 builds the SearchBuilder with the *SearchService* as scope
    # (`search_service.search_builder` → `new(self)`), which exposes neither
    # helper — the acting user rides in the service context instead (see
    # CatalogController#search_service_context). Without the context branch,
    # gated_user is nil on every search_service-built query (container/set
    # contents, the catalog index), silently collapsing discovery to
    # public-only — ignoring group membership and the admin short-circuit.
    def gated_user
      return scope.effective_user if scope.respond_to?(:effective_user)
      return scope.current_user   if scope.respond_to?(:current_user)
      return unless scope.respond_to?(:context)

      context = scope.context || {}
      context[:effective_user] || context[:current_user]
    end

    def discovery_permissions
      permissions = ['public']
      permissions.concat(Array(gated_user&.groups))
      permissions.uniq
    end
end
