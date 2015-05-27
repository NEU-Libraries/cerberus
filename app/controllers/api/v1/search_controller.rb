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
        (@response, @document_list) = get_search_results
        @pagination = paginate_params(@response)

        if @pagination.current_page > @pagination.num_pages
          render json: {error: "The page you've requested is more than is available.", pagination: @pagination} and return
        end

        render json: {pagination: @pagination, response: @response}
      end

    end
  end
end
