# frozen_string_literal: true

# Loads the scoped ImpressionsReport + Composition report for a
# Collection/Community edit page's Analytics tab. Gated on the same :edit
# ability as the other edit tabs, with the item lookup and facet drill-down
# permanently contained to this container's own subtree. See
# docs/analytics.md.
module ContainerAnalytics
  extend ActiveSupport::Concern

  private

    # `resource` needs .id (noid), .valkyrie_id (Solr uuid) and .title;
    # `klass` is 'Collection' or 'Community'.
    def load_container_analytics(resource, klass)
      @analytics_base_item = { noid: resource.id, uuid: resource.valkyrie_id, klass:, title: resource.title }
      descendants = ContainerDescendantsQuery.new(noid: @analytics_base_item[:noid], uuid: @analytics_base_item[:uuid])
      @analytics_effective_item = contained_drilldown_item(descendants) || @analytics_base_item

      scope = ImpressionScope.new(item: @analytics_effective_item, facet: analytics_facet_params)
      @analytics = ImpressionsReport.new(scope:)
      @analytics_composition = RepositoryCompositionReport.new(scope_fq: descendants.subtree_fq)
      @analytics_item_results = analytics_item_search(descendants)
      @analytics_facet_groups = analytics_facet_groups(descendants)
    end

    def analytics_item_params
      return nil if params[:analytics_item_noid].blank?

      { noid: params[:analytics_item_noid], uuid: params[:analytics_item_uuid],
        klass: params[:analytics_item_klass], title: params[:analytics_item_title] }
    end

    # THE containment boundary, not the search box: a drill-down arrives as
    # plain GET params an editor can hand-edit, so every candidate is
    # re-validated against the subtree before it is honoured.
    def contained_drilldown_item(descendants)
      candidate = analytics_item_params
      return nil if candidate.blank?

      contained =
        if candidate[:klass].to_s.in?(%w[Collection Community])
          descendants.container_uuids.include?(candidate[:uuid])
        else
          descendants.work_noids.include?(candidate[:noid].to_s.delete_prefix('id-'))
        end

      contained ? candidate : nil
    end

    def analytics_facet_params
      type, value = parsed_analytics_facet
      return nil if type.blank? || value.blank?

      { type:, value: }
    end

    # Both shapes are needed: the <select> emits only the packed
    # analytics_facet ("content::Image"), while every link this tab renders
    # uses the type/value pair — dropping either breaks a shared URL.
    def parsed_analytics_facet
      if params[:analytics_facet].present?
        params[:analytics_facet].to_s.split('::', 2)
      else
        [params[:analytics_facet_type], params[:analytics_facet_value]]
      end
    end

    # Deliberately un-gated: reuses ResourceSearch#filters without #call's
    # gated-discovery SearchBuilder, so an editor finds every item in their
    # own subtree whatever its visibility. Reads the bare `q` param, not
    # analytics_q — the shared admin/finder/_search_form partial names it.
    def analytics_item_search(descendants)
      return nil if params[:q].blank?

      filters = ResourceSearch.new(scope: self, query: params[:q], types: %w[Work Collection Community],
                                   within_fq: descendants.subtree_fq).filters
      Blacklight.default_index.search(q: params[:q].to_s, fq: filters, rows: ResourceSearch::DEFAULT_PER_PAGE)
    end

    # Only the Content type group is subtree-filtered; Featured Content
    # genres aren't Solr-derived, so they cannot be.
    def analytics_facet_groups(descendants)
      content_values = SolrFacetValues.call(
        field: 'classification_ssim', extra_fq: ['internal_resource_tesim:Work', descendants.subtree_fq]
      ).map(&:first)
      [
        ['Content type', content_values.map { |v| [v, "content::#{v}"] }],
        ['Featured Content', FeaturedContent.genre_labels.map { |v| [v, "featured::#{v}"] }]
      ]
    end
end
