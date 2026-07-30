# frozen_string_literal: true

require 'csv'

module Admin
  # Repository-wide usage analytics over the derived impression rollups.
  # Reachable by :admin and by the devolved-admin tier (User#admin_delegate?) —
  # purely local reads (ImpressionsReport, Cerberus's own TimescaleDB rollups),
  # no Atlas dependency either way. Reads never touch raw rows — only the
  # human-counts / continuous-aggregate / container rollups (a scoped view's
  # unique-visitors series is the one exception — see ImpressionsReport).
  #
  # Optionally scoped to one Work/Collection/Community (typeahead item picker,
  # reusing the admin finder idiom from reparent/linked-members) and/or a
  # Content-type or Featured-Content facet, combinable per ImpressionScope.
  class ImpressionsController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    # Needed for ResourceSearch's SearchBuilder chain (the item picker) — same
    # reason ReparentController includes it.
    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    breadcrumb_for 'Usage analytics', :admin_impressions_path

    XLSX_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

    # Anything can be the scoped item — a Work, a Collection, or a Community.
    ITEM_TYPES = %w[Work Collection Community].freeze

    def index
      @report = build_report
      @item_results = search_items if params[:q].present?
      @composition = RepositoryCompositionReport.new
    end

    # CSV / Excel of the top-N tables (the quarterly-report artifact). Format
    # comes off the URL extension (.csv / .xlsx); no Mime registration needed.
    def export
      report = build_report
      if params[:format] == 'xlsx'
        send_data ImpressionsExport.new(report).xlsx, filename: filename(report, 'xlsx'), type: XLSX_TYPE
      else
        send_data ImpressionsExport.new(report).csv, filename: filename(report, 'csv'), type: 'text/csv'
      end
    end

    private

      def build_report
        ImpressionsReport.new(range: parsed_range, segment: params[:segment], scope: build_scope)
      end

      def build_scope
        return nil if item_params.blank? && facet_params.blank?

        ImpressionScope.new(item: item_params, facet: facet_params)
      end

      def item_params
        return nil if params[:item_noid].blank?

        { noid: params[:item_noid], uuid: params[:item_uuid],
          klass: params[:item_klass], title: params[:item_title] }
      end

      def facet_params
        type, value = parsed_facet
        return nil if type.blank? || value.blank?

        { type:, value: }
      end

      # Accepts either the packed single-select `facet` param ("content::Image")
      # the facet <select> itself submits, or the canonical `facet_type` /
      # `facet_value` pair every link this dashboard renders uses (clear links,
      # export, the date-range/segment forms) — so a bookmarked or shared URL
      # round-trips cleanly even though the picker only ever emits the packed
      # form.
      def parsed_facet
        if params[:facet].present?
          params[:facet].to_s.split('::', 2)
        else
          [params[:facet_type], params[:facet_value]]
        end
      end

      def search_items
        ResourceSearch.call(scope: self, query: params[:q], types: ITEM_TYPES)
      end

      def parsed_range
        from = parse_date(params[:from]) || ImpressionsReport::DEFAULT_DAYS.days.ago.to_date
        to   = parse_date(params[:to]) || Date.current
        from..to
      end

      def parse_date(value)
        Date.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end

      def filename(report, ext)
        "impressions-#{report.range.begin}_#{report.range.end}-#{report.segment}.#{ext}"
      end
  end
end
