class SignificantContentController < ApplicationController 

  include Blacklight::Catalog

  # Load config information from CatalogController
  include Blacklight::Configurable
  self.copy_blacklight_config_from(CatalogController)

  include BlacklightAdvancedSearch::ParseBasicQ
  include BlacklightAdvancedSearch::Controller

  # This applies appropriate access controls to all solr queries 
  # (the internal method of this is overidden bellow to only include edit files)
  self.solr_search_params_logic += [:add_access_controls_to_solr_params]
  # This filters out objects that you want to exclude from search results, like FileAssets
  self.solr_search_params_logic += [:exclude_unwanted_models]

  layout :resolve_layout

  def research 
    @content = fetch_all(:research_publications)
  end

  def presentations 
    @content = fetch_all(:presentations) 
  end

  private 

    def fetch_all(content_type) 
      Community.all.inject([]) { |acc, dept| acc + dept.send(content_type) }
    end
end