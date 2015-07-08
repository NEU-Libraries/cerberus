require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

module Api
  module V1
    class SearchController < ApplicationController

      include Blacklight::Catalog
      include Blacklight::CatalogHelperBehavior
      include Blacklight::Configurable # comply with BL 3.7
      include ActionView::Helpers::DateHelper
      # This is needed as of BL 3.7
      self.copy_blacklight_config_from(CatalogController)
      include BlacklightAdvancedSearch::ParseBasicQ
      include BlacklightAdvancedSearch::Controller

      def search

        begin
          @set = fetch_solr_document
          # Must be a community or a compilation
          if @set.klass != "Collection" && @set.klass != "Compilation"
            render json: {error: "ID must match either a Collection or a Set"} and return
          end
        rescue ActiveFedora::ObjectNotFoundError
          render json: {error: "A valid starting ID is required"} and return
        end

        # Starting obj must be public
        if !@set.public?
          render json: {error: "ID must be for a public item"} and return
        end

        self.solr_search_params_logic += [:limit_to_public]

        # If the pid is a compilation, we need to get the pids and fake the search
        if @set.klass == "Compilation"
          comp = Compilation.find(@set.pid)
          pids = comp.entry_ids
          (@response, @document_list) = get_solr_response_for_field_values('id', pids, {}).first
        else
          self.solr_search_params_logic += [:limit_to_scope]
          (@response, @document_list) = get_search_results
        end

        @pagination = paginate_params(@response)

        if @pagination.total_count == 0
          render json: {error: "There were no results matching your query.", pagination: @pagination} and return
        end

        if @pagination.current_page > @pagination.num_pages
          render json: {error: "The page you've requested is more than is available.", pagination: @pagination} and return
        end

        render json: {pagination: @pagination, response: @response}
      end

      protected

        def limit_to_scope(solr_parameters, user_parameters)
          descendents = @set.combined_set_descendents

          # Limit query to items that are set descendents
          # or files off set descendents
          query = descendents.map do |set|
            p = set.pid
            set = "id:\"#{p}\" OR is_member_of_ssim:\"info:fedora/#{p}\""
          end

          # Ensure files directly on scoping collection are added in
          # as well
          query << "is_member_of_ssim:\"info:fedora/#{@set.pid}\""

          fq = query.join(" OR ")

          solr_parameters[:fq] ||= []
          solr_parameters[:fq] << fq
        end

        def limit_to_public(solr_parameters, user_parameters)
          solr_parameters[:fq] ||= []
          solr_parameters[:fq] << "read_access_group_ssim:\"public\""
          solr_parameters[:fq] << "-embargo_release_date_dtsi:[* TO *]"
        end

    end
  end
end
