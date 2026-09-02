# frozen_string_literal: true

# Item-lookup and facet-picker controls for the Collection/Community edit
# page's Analytics tab. Every URL built here routes back to the SAME edit
# page, anchored to #analytics, and is built only from noids/uuids
# ContainerAnalytics has already contained. See docs/analytics.md.
module ContainerAnalyticsHelper
  ITEM_PARAMS  = %w[analytics_item_noid analytics_item_uuid analytics_item_klass analytics_item_title].freeze
  FACET_PARAMS = %w[analytics_facet analytics_facet_type analytics_facet_value].freeze

  def container_analytics_drilled?(base_item, effective_item)
    effective_item[:noid].to_s != base_item[:noid].to_s
  end

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

  # Append the fragment as a string, never url_for's :anchor option: +params+
  # is usually a HashWithIndifferentAccess, merging :anchor stringifies the
  # key, and url_for honours only the symbol — the anchor would silently
  # become an "anchor=analytics" query param and the tab would be lost.
  def container_analytics_path(klass, noid, params = {})
    path_helper = klass == 'Community' ? :edit_community_path : :edit_collection_path
    "#{public_send(path_helper, noid, params)}#analytics"
  end

  def container_analytics_preserved_params(*except)
    request.query_parameters.except('q', *except)
  end

  # Drops back to the base container's own scope, never fully unscoped.
  def container_analytics_clear_item_path(klass, noid)
    container_analytics_path(klass, noid, request.query_parameters.except('q', *ITEM_PARAMS))
  end

  def container_analytics_clear_facet_path(klass, noid)
    container_analytics_path(klass, noid, request.query_parameters.except(*FACET_PARAMS))
  end

  def container_analytics_item_select_url(klass, noid, doc)
    container_analytics_path(klass, noid, container_analytics_preserved_params.merge(
                                            'analytics_item_noid'  => doc.to_param,
                                            'analytics_item_uuid'  => doc.id,
                                            'analytics_item_klass' => doc.klass_type,
                                            'analytics_item_title' => finder_doc_title(doc)
                                          ))
  end

  def container_analytics_selected_facet_value(report)
    scope = report.scope
    return nil unless scope&.facet_active?

    "#{scope.facet_type}::#{scope.facet_value}"
  end

  def open_in_usage_analytics_params(effective_item, report)
    scope = report.scope
    params = { item_noid: effective_item[:noid], item_uuid: effective_item[:uuid],
               item_klass: effective_item[:klass], item_title: effective_item[:title] }
    params.merge!(facet_type: scope.facet_type, facet_value: scope.facet_value) if scope&.facet_active?
    params
  end
end
