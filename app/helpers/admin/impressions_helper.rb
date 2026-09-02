# frozen_string_literal: true

module Admin
  # Segment toggle, export links and item-picker / facet scoping UI for the
  # /admin usage-analytics dashboard. See docs/analytics.md.
  module ImpressionsHelper
    ITEM_PARAMS  = %w[item_noid item_uuid item_klass item_title].freeze
    FACET_PARAMS = %w[facet facet_type facet_value].freeze

    # Themed color cycle for the Composition tab's classification pie chart.
    COMPOSITION_COLORS = %w[#2666a6 #18bc9c #5d569b #6f42c1 #fd7e14 #e83e8c #3498db #20c997 #f39c12].freeze

    def usage_segment_link(report, segment, label)
      active = report.segment.to_s == segment
      link_to label,
              admin_impressions_path(request.query_parameters.merge(segment:)),
              class: "usage-toggle__option #{'is-active' if active}".strip,
              'aria-pressed' => active.to_s
    end

    def usage_export_params(report)
      { from: report.range.begin, to: report.range.end, segment: report.segment }
        .merge(request.query_parameters.slice(*ITEM_PARAMS, 'facet_type', 'facet_value'))
    end

    def usage_preserved_params(*except)
      request.query_parameters.except('q', *except)
    end

    def usage_clear_item_path
      admin_impressions_path(request.query_parameters.except('q', *ITEM_PARAMS))
    end

    def usage_clear_facet_path
      admin_impressions_path(request.query_parameters.except(*FACET_PARAMS))
    end

    # Stays a helper so the finder results partial's select_url lambda is a
    # single HAML line — a multi-line lambda there trips Haml's
    # indentation-consistency check.
    def usage_item_select_url(doc)
      admin_impressions_path(usage_preserved_params.merge(
                               item_noid: doc.to_param, item_uuid: doc.id,
                               item_klass: doc.klass_type, item_title: finder_doc_title(doc)
                             ))
    end

    # option_value packs "type::value", parsed back by
    # Admin::ImpressionsController#parsed_facet: Content values are
    # Solr-discovered strings that can collide with a genre label.
    def usage_facet_groups
      content_values = SolrFacetValues.call(field:    'classification_ssim',
                                            extra_fq: ['internal_resource_tesim:Work']).map(&:first)
      [
        ['Content type', content_values.map { |v| [v, "content::#{v}"] }],
        ['Featured Content', FeaturedContent.genre_labels.map { |v| [v, "featured::#{v}"] }]
      ]
    end

    def usage_selected_facet_value(report)
      scope = report.scope
      return nil unless scope&.facet_active?

      "#{scope.facet_type}::#{scope.facet_value}"
    end

    def usage_composition_colors
      COMPOSITION_COLORS
    end
  end
end
