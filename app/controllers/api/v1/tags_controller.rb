require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

module Api
  module V1
    class TagsController < ApplicationController

      include Blacklight::Catalog
      include Blacklight::CatalogHelperBehavior
      include Blacklight::Configurable # comply with BL 3.7
      include ActionView::Helpers::DateHelper
      # This is needed as of BL 3.7
      self.copy_blacklight_config_from(CatalogController)
      include BlacklightAdvancedSearch::ParseBasicQ
      include BlacklightAdvancedSearch::Controller

      prepend_before_filter :authenticate_request!
      before_filter :enforce_show_permissions, :only=>:search
      after_filter :clear_api_user

      self.solr_search_params_logic += [:add_access_controls_to_solr_params]

      def search
        self.solr_search_params_logic += [:tag_filter]
        self.solr_search_params_logic += [:no_in_progress]
        self.solr_search_params_logic += [:disable_facet_limit]

        (@response, @document_list) = get_search_results
        @pagination = paginate_params(@response)

        if @pagination.total_count == 0
          render json: {error: "There were no results matching your query.", pagination: @pagination} and return
        end

        if @pagination.current_page > @pagination.num_pages
          render json: {error: "The page you've requested is more than is available.", pagination: @pagination} and return
        end

        # If response has facets, zip them together for easier parsing
        if !@response.facet_counts["facet_fields"].blank?
          @response.facet_counts["facet_fields"].each { |k, v| @response.facet_counts["facet_fields"][k] = Hash[v.each_slice(2).to_a] }
        end

        render json: {pagination: @pagination, response: @response}
      end

      protected

        def tag_filter(solr_parameters, user_parameters)
          # topic_tesim example
          solr_parameters[:fq] ||= []
          solr_parameters[:fq] << "tag_tesim:\"#{params[:id]}\""
        end

        def no_in_progress(solr_parameters, user_parameters)
          solr_parameters[:fq] ||= []
          solr_parameters[:fq] << "-in_progress_tesim:true OR -incomplete_tesim:true"
          # solr_parameters[:fq] << "-(-embargo_release_date_dtsi:[* TO NOW] OR embargo_release_date_dtsi:[* TO *])"
        end

        def disable_facet_limit(solr_parameters, user_parameters)
          solr_parameters["facet.limit"] = "-1"
        end

    end
  end
end
