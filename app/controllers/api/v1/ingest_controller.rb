require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

module Api
  module V1
    class IngestController < ApplicationController

      include Blacklight::Catalog
      include Blacklight::CatalogHelperBehavior
      include Blacklight::Configurable # comply with BL 3.7
      include ActionView::Helpers::DateHelper
      # This is needed as of BL 3.7
      self.copy_blacklight_config_from(CatalogController)
      include BlacklightAdvancedSearch::ParseBasicQ
      include BlacklightAdvancedSearch::Controller

      def ingest
        # Take an external form, and based on whitelisted IP deposit submission

        # Required items;
        # Binary file
        # Title
        # Keyword(s)

        # Optional items;
        # Subtitle
        # Creator name(s) - first, middle, last
        # Date created
        # Copyright date
        # Date published
        # Publisher name
        # Place of publication
        # Language(s)
        # Description(s)
        # Note(s)
        # Use and reproduction - dropdown
      end

    end
  end
end
