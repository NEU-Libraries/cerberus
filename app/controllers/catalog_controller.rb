# -*- coding: utf-8 -*-
# -*- encoding : utf-8 -*-
require 'blacklight/catalog'
require 'blacklight_advanced_search'

# bl_advanced_search 1.2.4 is doing unitialized constant on these because we're calling ParseBasicQ directly
require 'parslet'
require 'parsing_nesting/tree'

class CatalogController < ApplicationController
  include Blacklight::Catalog
  # Extend Blacklight::Catalog with Hydra behaviors (primarily editing).
  include Hydra::Controller::ControllerBehavior
  include BlacklightAdvancedSearch::ParseBasicQ

  # These before_filters apply the hydra access controls
  before_filter :enforce_show_permissions, :only=>:show
  # This applies appropriate access controls to all solr queries
  CatalogController.solr_search_params_logic += [:add_access_controls_to_solr_params]
  # This filters out objects that you want to exclude from search results, like FileAssets
  # Kept as an example of how to do this
  #CatalogController.solr_search_params_logic += [:exclude_unwanted_models]

  CatalogController.solr_search_params_logic += [:no_incomplete_records]

  # While compilations can be public we don't want them to be discoverable
  CatalogController.solr_search_params_logic += [:exclude_compilations]

  skip_before_filter :default_html_head

  def bad_route
    params.clear

    flash[:error] = "Sorry - the page you requested, #{params[:error]}, was not found in the system."
    flash[:alert] = "If you were trying to access an item in IRis, our previous institutional repository, please perform a search to locate it in the DRS."
    self.solr_search_params_logic += [:disable_highlighting]
    recent
    respond_to do |format|
      format.html { render :template => 'catalog/index', :status => 404 }
      format.any { render_404(ActiveFedora::ObjectNotFoundError.new) }
    end
  end

  def index

    if !params[:q].nil?
      # Fixes #667 - we remove single characters. They're a pretty terrible idea with a strict AND
      params[:q].gsub!(/(^| ).( |$)/, ' ')
    end

    if !has_search_parameters?
      self.solr_search_params_logic += [:disable_highlighting]
      recent
    else
      super
    end
  end

  def facet
    # Kludgey kludge kludge
    params[:solr_field] = params[:id]
    # Put in logic handling the smart collections
    if params[:smart_collection]
      filter_name = "#{params[:smart_collection].to_s}_filter"
      self.solr_search_params_logic += [filter_name.to_sym]
      (_, @document_list) = get_search_results
      @pagination = get_facet_pagination(params[:id], params)
      respond_to do |format|
        # Draw the facet selector for users who have javascript disabled:
        format.html { render :template => 'catalog/facet' }
        # Draw the partial for the "more" facet modal window:
        format.js { render :template => 'catalog/facet', :layout => false }
      end
    else
      super
    end
  end

  def recent
    self.solr_search_params_logic += [:exclude_unwanted_models]
    self.solr_search_params_logic += [:no_personal_items]

    # Due to errors or poor metadata in Fedora, we need to check for title
    self.solr_search_params_logic += [:well_formed_items]

    (_, @recent_documents) = get_search_results(:q =>'', :sort=>"#{Solrizer.solr_name('system_create', :stored_sortable, type: :date)} desc", :rows=>999)
    # if user_signed_in?
    #   # grab other people's documents
    #   (_, @recent_documents) = get_search_results(:q =>filter_not_mine,
    #                                     :sort=>sort_field, :rows=>3)
    # else
    #   # grab any documents we do not know who you are
    #   (_, @recent_documents) = get_search_results(:q =>'', :sort=>sort_field, :rows=>3)
    # end
  end

  def recent_me
    if user_signed_in?
      (_, @recent_user_documents) = get_search_results(:q =>filter_mine,
                                        :sort=>"#{Solrizer.solr_name('system_create', :stored_sortable, type: :date)} desc", :rows=>3)
    end
  end

  def communities
    self.solr_search_params_logic += [:communities_filter]
    (@response, @document_list) = get_search_results
    render 'smart_collection', locals: { smart_collection: 'communities' }
  end

  def research
    self.solr_search_params_logic += [:research_filter]
    (@response, @document_list) = get_search_results
    render 'smart_collection', locals: { smart_collection: 'research' }
  end

  def presentations
    self.solr_search_params_logic += [:presentations_filter]
    (@response, @document_list) = get_search_results
    render 'smart_collection', locals: { smart_collection: 'presentations' }
  end

  def datasets
    self.solr_search_params_logic += [:datasets_filter]
    (@response, @document_list) = get_search_results
    render 'smart_collection', locals: { smart_collection: 'datasets' }
  end

  def monographs
    self.solr_search_params_logic += [:monographs_filter]
    (@response, @document_list) = get_search_results
    render 'smart_collection', locals: { smart_collection: 'monographs' }
  end

  def faculty_and_staff
    self.solr_search_params_logic += [:faculty_and_staff_filter]
    (@response, @document_list) = get_search_results
    render 'smart_collection', locals: { smart_collection: 'employees' }
  end

  def theses_and_dissertations
    self.solr_search_params_logic += [:theses_and_dissertations_filter]
    (@response, @document_list) = get_search_results
    render 'smart_collection', locals: { smart_collection: 'theses' }
  end

  def self.uploaded_field
    solr_name('system_create', :stored_sortable, type: :date)
  end

  def self.created_field
    solr_name('system_modified', :stored_sortable, type: :date)
  end

  def self.title_field
    solr_name('title', :stored_sortable, type: :string)
  end

  def self.creator_field
    solr_name('creator', :stored_sortable, type: :string)
  end

  configure_blacklight do |config|
    ## Default parameters to send to solr for all search-like requests. See also SolrHelper#solr_search_params
    config.default_solr_params = {
      :qt => "search",
      "facet.limit" => "5",
      :rows => 10
    }

    # solr field configuration for search results/index views
    # config.index.show_link = solr_name("desc_metadata__title", :displayable)
    # config.index.record_display_type = "id"

    # solr field configuration for document/show views
    # config.show.html_title = solr_name("desc_metadata__title", :displayable)
    # config.show.heading = solr_name("desc_metadata__title", :displayable)
    # config.show.display_type = solr_name("has_model", :symbol)

    # solr fields that will be treated as facets by the blacklight application
    #   The ordering of the field names is the order of the display
    # copyright
    # config.add_facet_field solr_name("origin_info_copyright", :facetable), label: "Copyright", limit: 5
    config.add_facet_field solr_name("creator", :facetable), label: "Creator", limit: true
    config.add_facet_field solr_name("creation_year", :facetable), label: "Year", limit: true
    config.add_facet_field solr_name("drs_department", :symbol), label: "Department", limit: true
    config.add_facet_field solr_name("drs_degree", :symbol), label: "Degree Level", limit: true
    config.add_facet_field solr_name("drs_course_number", :symbol), label: "Course Number", limit: true
    config.add_facet_field solr_name("drs_course_title", :symbol), label: "Course Title", limit: true
    config.add_facet_field solr_name("subject", :facetable), label: "Subject", limit: true
    config.add_facet_field solr_name("type", :facetable), label: "Type", limit: true
    config.add_facet_field solr_name("community_name", :symbol), label: "Community", limit: true

    # Have BL send all facet field names to Solr, which has been the default
    # previously. Simply remove these lines if you'd rather use Solr request
    # handler defaults, or have no facets.
    config.add_facet_fields_to_solr_request!

    # "fielded" search configuration. Used by pulldown among other places.
    # For supported keys in hash, see rdoc for Blacklight::SearchFields
    #
    # Search fields will inherit the :qt solr request handler from
    # config[:default_solr_parameters], OR can specify a different one
    # with a :qt key/value. Below examples inherit, except for subject
    # that specifies the same :qt as default for our own internal
    # testing purposes.
    #
    # The :key is what will be used to identify this BL search field internally,
    # as well as in URLs -- so changing it after deployment may break bookmarked
    # urls.  A display label will be automatically calculated from the :key,
    # or can be specified manually to be different.
    #
    # This one uses all the defaults set by the solr request handler. Which
    # solr request handler? The one set in config[:default_solr_parameters][:qt],
    # since we aren't specifying it otherwise.
    config.add_search_field('all_fields', label: 'All Fields', include_in_advanced_search: false) do |field|
      # These are generated by the mods datastream
      title = "title_tesim"
      abstract = "abstract_tesim"
      genre = "genre_tesim"
      topic = "subject_topic_tesim"
      creators = "creator_tesim"
      publisher = "origin_info_publisher_tesim"
      place = "origin_info_place_tesim"
      identifier = "identifier_tesim"
      emp_name = "employee_name_tesim"
      emp_nuid = "employee_nuid_ssim"
      all_text = "all_text_timv"

      field.solr_parameters = {
        qf: "#{title} #{abstract} #{genre} #{topic} #{creators} #{publisher} #{place} #{identifier} #{emp_name} #{emp_nuid} #{all_text}",
        pf: "#{title}",
      }
    end


    # Now we see how to over-ride Solr request handler defaults, in this
    # case for a BL "search field", which is really a dismax aggregate
    # of Solr search fields.
    # creator, title, description, publisher, date_created,
    # subject, language, resource_type, format, identifier, based_near,

    # Commenting out because we no longer have desc_metadata, but want it here for posterity.

    # config.add_search_field('contributor') do |field|
    #   # solr_parameters hash are sent to Solr as ordinary url query params.
    #   field.solr_parameters = { :"spellcheck.dictionary" => "contributor" }

    #   # :solr_local_parameters will be sent using Solr LocalParams
    #   # syntax, as eg {! qf=$title_qf }. This is neccesary to use
    #   # Solr parameter de-referencing like $title_qf.
    #   # See: http://wiki.apache.org/solr/LocalParams
    #   solr_name = solr_name("desc_metadata__contributor", :stored_searchable, type: :string)
    #   field.solr_local_parameters = {
    #     :qf => solr_name,
    #     :pf => solr_name
    #   }
    # end


    # "sort results by" select (pulldown)
    # label in pulldown is followed by the name of the SOLR field to sort by and
    # whether the sort is ascending or descending (it must be asc or desc
    # except in the relevancy case).
    # label is key, solr field is value
    config.add_sort_field "#{title_field} asc", :label => "Title"
    config.add_sort_field "#{creator_field} asc", :label => "Creator, A-Z"
    config.add_sort_field "#{creator_field} desc", :label => "Creator, Z-A"
    config.add_sort_field "#{uploaded_field} desc", :label => "Recently added"
    config.add_sort_field "#{created_field} desc", :label => "Recently created"
    config.add_sort_field "score desc, #{uploaded_field} desc", :label => "Relevance"

    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 5
  end

  protected

  # Limits search results just to CoreFiles
  # @param solr_parameters the current solr parameters
  # @param user_parameters the current user-subitted parameters
  def exclude_unwanted_models(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:CoreFile\""
    solr_parameters[:fq] << "-#{Solrizer.solr_name("is_supplemental_material_for", :symbol)}:[* TO *]"
  end

  def exclude_compilations(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "-active_fedora_model_ssi:\"Compilation\""
  end

  def depositor
    #Hydra.config[:permissions][:owner] maybe it should match this config variable, but it doesn't.
    Solrizer.solr_name('depositor', :stored_searchable, type: :string)
  end

  def filter_not_mine
    "{!lucene q.op=AND df=#{depositor}}-#{current_user.user_key}"
  end

  def filter_mine
    "{!lucene q.op=AND df=#{depositor}}#{current_user.user_key}"
  end

  def sort_field
    "#{Solrizer.solr_name('system_create', :sortable)} desc"
  end

  def search_layout
    "homepage"
  end

  def no_personal_items(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "-#{Solrizer.solr_name("drs_category", :symbol)}:\"miscellany\""
  end

  def well_formed_items(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "#{Solrizer.solr_name('title_info_title', :stored_sortable, type: :string)}:\[\* TO \*\]"
  end

  def communities_filter(solr_parameters, user_parameters)
    model_type = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:Community"
    query = "has_model_ssim:\"#{model_type}\""
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  def research_filter(solr_parameters, user_parameters)
    query = "drs_category_ssim:\"Research Publications\""
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  def presentations_filter(solr_parameters, user_parameters)
    query = "drs_category_ssim:\"Presentations\""
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  def datasets_filter(solr_parameters, user_parameters)
    query = "drs_category_ssim:\"Datasets\""
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  def faculty_and_staff_filter(solr_parameters, user_parameters)
    query = "active_fedora_model_ssi:\"Employee\""
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  def theses_and_dissertations_filter(solr_parameters, user_parameters)
    query = "drs_category_ssim:\"Theses and Dissertations\""
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  def monographs_filter(solr_parameters, user_parameters)
    query = "drs_category_ssim:\"Monographs\""
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  def no_incomplete_records(solr_parameters, user_parameters)
    query = "-in_progress_tesim:true OR -incomplete_tesim:true"

    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  def disable_highlighting(solr_parameters, user_parameters)
    solr_parameters[:hl] = "false"
  end
end
