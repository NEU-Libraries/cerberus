# frozen_string_literal: true

# Loads the scoped ImpressionsReport + Composition report for a
# Collection/Community edit page's Analytics tab — shared by
# CollectionsController and CommunitiesController. Visible to anyone who can
# reach the edit page at all (the same :edit ability gate as the
# Metadata/Permissions tabs — no separate admin check): a group editor's own
# container's traffic isn't privileged information the way the repo-wide
# /admin dashboard's cross-container view is. The shared partial
# (shared/_container_analytics) separately gates the "Open in Usage
# Analytics" drill-down link on admin/admin_delegate, since that link leads
# to the admin-only dashboard and would otherwise 403 for most viewers.
#
# Adds the same item-lookup + facet drill-down the admin dashboard has, but
# permanently CONTAINED to this container's own subtree (self + descendant
# containers + every descendant Work) — an editor can narrow their own view
# further, never escape it. The item-lookup search box only ever returns
# subtree-contained results (ResourceSearch's within_fq), but a drill-down
# also arrives as plain GET params an editor could hand-edit, so
# #contained_drilldown_item re-validates every drill-down against the
# subtree before honoring it — that check, not the search box, is the actual
# containment boundary.
#
# Composition, unlike Overview/Top files/Top collections, ignores the
# drill-down entirely — mirrors the admin dashboard's own Composition tab,
# which is always unscoped by item/facet; here it's always "composition of
# this container's own subtree," regardless of what's drilled into above it.
module ContainerAnalytics
  extend ActiveSupport::Concern

  private

    # @param resource [AtlasRb::Collection, AtlasRb::Community] the container
    #   being edited — needs .id (noid), .valkyrie_id (Solr uuid), and .title.
    # @param klass [String] 'Collection' or 'Community'.
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

    # @return [Hash, nil] the drill-down item params, but only when the
    #   candidate actually resolves inside this container's subtree — the
    #   real containment check (see the class comment above).
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

    # Accepts either the packed single-select analytics_facet param
    # ("content::Image") the facet <select> itself submits, or the canonical
    # analytics_facet_type/analytics_facet_value pair every link this tab
    # renders uses (clear links) — mirrors Admin::ImpressionsController's
    # #parsed_facet for the same reason: a bookmarked or shared URL round-trips
    # cleanly even though the picker only ever emits the packed form.
    def parsed_analytics_facet
      if params[:analytics_facet].present?
        params[:analytics_facet].to_s.split('::', 2)
      else
        [params[:analytics_facet_type], params[:analytics_facet_value]]
      end
    end

    # Un-gated (bypasses ResourceSearch's own SearchBuilder/gated-discovery
    # chain) — a group editor must be able to find every item in their own
    # container's subtree regardless of that item's own visibility, the same
    # reason the rest of container analytics reads system-wide. Reuses
    # ResourceSearch#filters (pure, already covers type + tombstone + within_fq)
    # without its #call's gated-discovery SearchBuilder path.
    #
    # Reads the bare `q` param (not analytics_q) — the item-lookup box is
    # rendered via the shared admin/finder/_search_form partial, which submits
    # a field literally named `q`; every other analytics param is our own and
    # gets the analytics_ prefix, but this one field name isn't ours to pick.
    def analytics_item_search(descendants)
      return nil if params[:q].blank?

      filters = ResourceSearch.new(scope: self, query: params[:q], types: %w[Work Collection Community],
                                   within_fq: descendants.subtree_fq).filters
      Blacklight.default_index.search(q: params[:q].to_s, fq: filters, rows: ResourceSearch::DEFAULT_PER_PAGE)
    end

    # Grouped <select> options for the facet picker, restricted to
    # classifications that actually occur within this subtree (Featured
    # Content genres aren't Solr-derived, so they're never subtree-filterable
    # — same as the admin dashboard's own picker).
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
