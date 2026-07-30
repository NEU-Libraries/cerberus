# frozen_string_literal: true

module Admin
  # View helpers for the usage-analytics dashboard: chartkick-ready datasets,
  # the segment toggle, export links, and the item-picker / facet scoping UI.
  # Kept out of the controller (thin) and the report (data-only).
  module ImpressionsHelper
    ITEM_PARAMS  = %w[item_noid item_uuid item_klass item_title].freeze
    FACET_PARAMS = %w[facet facet_type facet_value].freeze

    # Per-action series as a chartkick multi-series array (string day keys).
    def usage_timeseries(report)
      ImpressionsReport::ACTIONS.map do |action|
        { name: action.capitalize, data: report.series(action).transform_keys(&:to_s) }
      end
    end

    def usage_visitors_series(report)
      [{ name: 'Unique visitors', data: report.unique_visitors_series.transform_keys(&:to_s) }]
    end

    # A segment-toggle option that preserves every other active param
    # (date range, item scope, facet) via the full current query string.
    def usage_segment_link(report, segment, label)
      active = report.segment.to_s == segment
      link_to label,
              admin_impressions_path(request.query_parameters.merge(segment:)),
              class: "usage-toggle__option #{'is-active' if active}".strip,
              'aria-pressed' => active.to_s
    end

    # Range/segment/scope params for the export links (format passed
    # separately) — so a scoped dashboard's CSV/Excel matches what's on screen.
    def usage_export_params(report)
      { from: report.range.begin, to: report.range.end, segment: report.segment }
        .merge(request.query_parameters.slice(*ITEM_PARAMS, 'facet_type', 'facet_value'))
    end

    # Hidden-field params a GET form must carry to avoid clobbering whatever
    # it doesn't itself edit — every current query param except `q` (a
    # search box's own field) and whatever the form's own inputs cover.
    def usage_preserved_params(*except)
      request.query_parameters.except('q', *except)
    end

    # href for the "scoped to: X ✕" chip's clear link.
    def usage_clear_item_path
      admin_impressions_path(request.query_parameters.except('q', *ITEM_PARAMS))
    end

    # href for the "faceted by: X ✕" chip's clear link.
    def usage_clear_facet_path
      admin_impressions_path(request.query_parameters.except(*FACET_PARAMS))
    end

    # href for picking one item-search result row as the new item scope.
    # Pulled out of the view so the finder results partial's select_url
    # lambda stays a single HAML line (a multi-line lambda there trips
    # Haml's indentation-consistency check).
    def usage_item_select_url(doc)
      admin_impressions_path(usage_preserved_params.merge(
                               item_noid: doc.to_param, item_uuid: doc.id,
                               item_klass: doc.klass_type, item_title: finder_doc_title(doc)
                             ))
    end

    # Grouped <select> options for the facet picker: [[group_label,
    # [[option_label, option_value], ...]], ...], the shape
    # grouped_options_for_select expects. option_value packs "type::value"
    # (parsed back by Admin::ImpressionsController#parsed_facet) — Content
    # values are Solr-discovered strings that could in principle collide with
    # a genre label, and "::" keeps the two namespaces unambiguous without a
    # second <select> + cascading JS for what's a ~20-option combined list.
    def usage_facet_groups
      content_values = SolrFacetValues.call(field:    'classification_ssim',
                                            extra_fq: ['internal_resource_tesim:Work']).map(&:first)
      [
        ['Content type', content_values.map { |v| [v, "content::#{v}"] }],
        ['Featured Content', FeaturedContent.genre_labels.map { |v| [v, "featured::#{v}"] }]
      ]
    end

    # The <select>'s current packed value, so re-rendering after a filter
    # keeps the picked option selected.
    def usage_selected_facet_value(report)
      scope = report.scope
      return nil unless scope&.facet_active?

      "#{scope.facet_type}::#{scope.facet_value}"
    end
  end
end
