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

      include Cerberus::TempFileStorage
      include Cerberus::ThumbnailCreation
      include HandleHelper
      include MimeHelper

      def ingest
        # Take an external form, and based on whitelisted IP deposit submission
        # core_file.instantiate_appropriate_content_object(tmp_path, core_file.original_filename)
        # Cerberus::Application::Queue.push(ContentCreationJob.new(@core_file.pid, @core_file.tmp_path, @core_file.original_filename))
        # core_file.identifier = make_handle(core_file.persistent_url)

        core_file = CoreFile.new

        # Required items;
        # Binary file
        file = params[:file]
        # Title
        title = params[:core_file][:title]
        # Keyword(s)
        keywords = params[:core_file][:keywords]

        # Optional items;
        # Subtitle
        subtitle = params[:core_file][:subtitle]
        # Date created
        date_created = params[:core_file][:date_created]
        # Copyright date
        copyright_date = params[:core_file][:copyright_date]
        # Date published
        date_published = params[:core_file][:date_published]
        # Publisher name
        publisher = params[:core_file][:publisher]
        # Place of publication
        place_of_publication = params[:core_file][:place_of_publication]
        # Creator name(s) - first, middle, last

        # Language(s)
        languages = params[:core_file][:languages]
        # Description(s)
        descriptions = params[:core_file][:descriptions]
        # Note(s)
        notes = params[:core_file][:notes]
        # Use and reproduction - dropdown
        use_and_reproduction = params[:core_file][:use_and_reproduction]
      end

    end
  end
end
