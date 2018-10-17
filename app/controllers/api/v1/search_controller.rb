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

      before_filter :enforce_show_permissions, :only=>:search
      before_filter :authenticate_request!
      after_filter :clear_user

      self.solr_search_params_logic += [:add_access_controls_to_solr_params]

      def clear_user
        sign_out(current_user)
      end

      def search

        begin
          @set = fetch_solr_document
          # Must be a community or a compilation
          if @set.klass != "Collection" && @set.klass != "Compilation"
            render json: {error: "ID must match either a Collection or a #{t('drs.compilations.name').capitalize}"} and return
          end
        rescue ActiveFedora::ObjectNotFoundError
          render json: {error: "A valid starting ID is required"} and return
        end

        # Starting obj must be public
        # if !@set.public?
        #   render json: {error: "ID must be for a public item"} and return
        # end

        # self.solr_search_params_logic += [:limit_to_public]
        self.solr_search_params_logic += [:no_in_progress_or_embargo]
        self.solr_search_params_logic += [:disable_facet_limit]

        # If the pid is a compilation, we need to get the pids and fake the search
        if @set.klass == "Compilation"
          comp = Compilation.find(@set.pid)
          @pids = comp.entry_ids
          if @pids.count > 0
            self.solr_search_params_logic += [:limit_to_compilation_scope]
          else
            render json: {error: "There were no results matching your query.", pagination: @pagination} and return
          end
        else
          self.solr_search_params_logic += [:limit_to_scope]
        end

        if params[:filter] == 'geo'
          self.solr_search_params_logic += [:limit_to_has_geo]
        elsif params[:filter] == 'date'
          self.solr_search_params_logic += [:limit_to_has_date]
        elsif params[:filter] == 'av'
          self.solr_search_params_logic += [:limit_to_av]
        else
          # no additional filter applied
        end

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

        def limit_to_compilation_scope(solr_parameters, user_parameters)
          query = @pids.map do |pid|
            doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first
            if doc.klass == "Collection"
              # if collection
              "parent_id_tesim:\"#{pid}\""
            else
              # else core file
              "id:\"#{pid}\""
            end
          end

          fq = query.join(" OR ")

          solr_parameters[:fq] ||= []
          solr_parameters[:fq] << fq
        end

        # def limit_to_public(solr_parameters, user_parameters)
        #   solr_parameters[:fq] ||= []
        #   solr_parameters[:fq] << "read_access_group_ssim:\"public\""
        # end

        def no_in_progress_or_embargo
          solr_parameters[:fq] ||= []
          solr_parameters[:fq] << "-in_progress_tesim:true OR -incomplete_tesim:true"
          solr_parameters[:fq] << "-(-embargo_release_date_dtsi:[* TO NOW] OR embargo_release_date_dtsi:[* TO *])"
        end

        def disable_facet_limit(solr_parameters, user_parameters)
          solr_parameters["facet.limit"] = "-1"
        end

        def limit_to_has_geo(solr_parameters, user_parameters)
          solr_parameters[:fq] ||= []
          solr_parameters[:fq] << "subject_geographic_tesim:[* TO *] OR subject_cartographics_coordinates_tesim:[* TO *]"
        end

        def limit_to_has_date(solr_parameters, user_parameters)
          solr_parameters[:fq] ||= []
          solr_parameters[:fq] << "key_date_ssi:[* TO *]"
        end

        def limit_to_av(solr_parameters, user_parameters)
          solr_parameters[:fq] ||= []
          solr_parameters[:fq] << "canonical_class_tesim:\"AudioFile\" OR canonical_class_tesim:\"VideoFile\""
        end

    end
  end
end
