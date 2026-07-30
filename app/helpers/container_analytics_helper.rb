# frozen_string_literal: true

# View helpers for the Collection/Community edit page's Analytics tab
# item-lookup + facet-picker controls — the container-scoped counterpart of
# Admin::ImpressionsHelper's scope-picker helpers. Every URL built here routes
# back to the SAME edit page, anchored to #analytics so a GET round-trip
# lands back on the right outer tab. The item search itself is what actually
# enforces subtree containment (see ContainerAnalytics#analytics_item_search);
# these helpers only ever construct URLs from noids/uuids the controller has
# already resolved or a search result already returned, so nothing here
# re-opens that boundary.
module ContainerAnalyticsHelper
  ITEM_PARAMS  = %w[analytics_item_noid analytics_item_uuid analytics_item_klass analytics_item_title].freeze
  FACET_PARAMS = %w[analytics_facet analytics_facet_type analytics_facet_value].freeze

  # Whether a drill-down to a descendant item is active, rather than the base
  # container's own scope.
  def container_analytics_drilled?(base_item, effective_item)
    effective_item[:noid].to_s != base_item[:noid].to_s
  end

  # The Analytics tab's intro sentence. Three shapes, because a fixed one
  # overclaims: "everything under this collection" sitting directly above
  # figures for a single drilled-into Work, or above facet-narrowed figures,
  # contradicts what the reader is looking at.
  def container_analytics_scope_blurb(report, base_item, effective_item)
    container = base_item[:klass].downcase
    subject =
      if container_analytics_drilled?(base_item, effective_item)
        "#{effective_item[:title]} — one #{effective_item[:klass].downcase} within this #{container}"
      elsif report.scope.facet_active?
        "the Works under this #{container} matching the facet below"
      else
        "everything under this #{container} — the #{container} itself and every descendant Work"
      end
    "Views, downloads, and visitors for #{subject}. " \
      "Last #{ImpressionsReport::DEFAULT_DAYS} days, human traffic only."
  end

  # The container's own edit path (Collection or Community), always anchored
  # back to the Analytics tab.
  #
  # The fragment is appended as a string rather than handed to url_for's
  # :anchor option because +params+ is usually request.query_parameters, a
  # HashWithIndifferentAccess — merging :anchor into one stringifies the key,
  # and url_for honors only the symbol, so the anchor would silently come out
  # as a literal "anchor=analytics" query param and the tab would be lost.
  def container_analytics_path(klass, noid, params = {})
    path_helper = klass == 'Community' ? :edit_community_path : :edit_collection_path
    "#{public_send(path_helper, noid, params)}#analytics"
  end

  # Hidden-field params a GET form must carry to avoid clobbering whatever it
  # doesn't itself edit — every current analytics query param except `q` (the
  # item-lookup search box's own field) and whatever the form's own inputs
  # cover.
  def container_analytics_preserved_params(*except)
    request.query_parameters.except('q', *except)
  end

  # href for the "Scoped to: X ✕" chip's clear link — drops back to the base
  # container's own scope (never fully unscoped; see ContainerAnalytics).
  def container_analytics_clear_item_path(klass, noid)
    container_analytics_path(klass, noid, request.query_parameters.except('q', *ITEM_PARAMS))
  end

  # href for the "Faceted by: X ✕" chip's clear link.
  def container_analytics_clear_facet_path(klass, noid)
    container_analytics_path(klass, noid, request.query_parameters.except(*FACET_PARAMS))
  end

  # href for picking one item-search result row as the drill-down scope.
  def container_analytics_item_select_url(klass, noid, doc)
    container_analytics_path(klass, noid, container_analytics_preserved_params.merge(
                                            'analytics_item_noid'  => doc.to_param,
                                            'analytics_item_uuid'  => doc.id,
                                            'analytics_item_klass' => doc.klass_type,
                                            'analytics_item_title' => finder_doc_title(doc)
                                          ))
  end

  # The <select>'s current packed value, so re-rendering after a filter keeps
  # the picked option selected.
  def container_analytics_selected_facet_value(report)
    scope = report.scope
    return nil unless scope&.facet_active?

    "#{scope.facet_type}::#{scope.facet_value}"
  end

  # Query params for the (admin-only) "Open in Usage Analytics" drill-down
  # link — carries the *effective* item (the drilled-into sub-item if one is
  # active, otherwise the container itself) and any active facet, so the full
  # dashboard opens already showing what's on screen here.
  def open_in_usage_analytics_params(effective_item, report)
    scope = report.scope
    params = { item_noid: effective_item[:noid], item_uuid: effective_item[:uuid],
               item_klass: effective_item[:klass], item_title: effective_item[:title] }
    params.merge!(facet_type: scope.facet_type, facet_value: scope.facet_value) if scope&.facet_active?
    params
  end
end
