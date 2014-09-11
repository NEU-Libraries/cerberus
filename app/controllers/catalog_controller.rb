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

  def index
    # Before executing the actual search (by calling super)
    # We check if scoped filtering needs to be added to the query

    if params["scope"] && params["smart_search"]
      self.solr_search_params_logic += [:limit_to_smart_search_scope]
    elsif params["scope"]
      self.solr_search_params_logic += [:limit_to_scope]
    end

    if !has_search_parameters?
      recent
    else
      self.solr_search_params_logic += [:full_text_search]
      super
    end
  end

  def recent
    self.solr_search_params_logic += [:exclude_unwanted_models]
    self.solr_search_params_logic += [:featured_content_only]
    (_, @recent_documents) = get_search_results(:q =>'', :sort=>"#{Solrizer.solr_name('system_create', :stored_sortable, type: :date)} desc", :rows=>3)
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

  def research
    self.solr_search_params_logic += [:research_filter]
    (@response, @document_list) = get_search_results
    render :template => 'communities/smart_collection'
  end

  def presentations
    self.solr_search_params_logic += [:presentations_filter]
    (@response, @document_list) = get_search_results
    render :template => 'catalog/index'
  end

  def datasets
    self.solr_search_params_logic += [:datasets_filter]
    (@response, @document_list) = get_search_results
    render :template => 'catalog/index'
  end

  def faculty_and_staff
    self.solr_search_params_logic += [:faculty_and_staff_filter]
    (@response, @document_list) = get_search_results
    render :template => 'catalog/index'
  end

  def theses_and_dissertations
    self.solr_search_params_logic += [:theses_and_dissertations_filter]
    (@response, @document_list) = get_search_results
    render :template => 'catalog/index'
  end

  def self.uploaded_field
#  system_create_dtsi
    solr_name('desc_metadata__date_uploaded', :stored_sortable, type: :date)
  end

  def self.modified_field
    solr_name('desc_metadata__date_modified', :stored_sortable, type: :date)
  end

  def self.title_field
    solr_name('title_info_title', :stored_sortable, type: :string)
  end

  configure_blacklight do |config|
    ## Default parameters to send to solr for all search-like requests. See also SolrHelper#solr_search_params
    config.default_solr_params = {
      :qt => "search",
      :rows => 10
    }

    # solr field configuration for search results/index views
    config.index.show_link = solr_name("desc_metadata__title", :displayable)
    config.index.record_display_type = "id"

    # solr field configuration for document/show views
    config.show.html_title = solr_name("desc_metadata__title", :displayable)
    config.show.heading = solr_name("desc_metadata__title", :displayable)
    config.show.display_type = solr_name("has_model", :symbol)

    # solr fields that will be treated as facets by the blacklight application
    #   The ordering of the field names is the order of the display
    # copyright
    # config.add_facet_field solr_name("origin_info_copyright", :facetable), label: "Copyright", limit: 5
    config.add_facet_field solr_name("creator", :facetable), label: "Creator", limit: 5
    config.add_facet_field solr_name("creation_year", :facetable), label: "Year", limit: 5
    config.add_facet_field solr_name("drs_department", :symbol), label: "Department", limit: 5
    config.add_facet_field solr_name("drs_degree", :symbol), label: "Degree Level", limit: 5
    config.add_facet_field solr_name("drs_course_number", :symbol), label: "Course Number", limit: 5
    config.add_facet_field solr_name("drs_course_title", :symbol), label: "Course Title", limit: 5
    config.add_facet_field solr_name("subject", :facetable), label: "Subject", limit: 5
    config.add_facet_field solr_name("type", :facetable), label: "Type", limit: 5
    config.add_facet_field solr_name("community_name", :symbol), label: "Community", limit: 5

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

      field.solr_parameters = {
        qf: "#{title} #{abstract} #{genre} #{topic} #{creators} #{publisher} #{place} #{identifier} #{emp_name} #{emp_nuid}",
        pf: "#{title}",
      }
    end


    # Now we see how to over-ride Solr request handler defaults, in this
    # case for a BL "search field", which is really a dismax aggregate
    # of Solr search fields.
    # creator, title, description, publisher, date_created,
    # subject, language, resource_type, format, identifier, based_near,
    config.add_search_field('contributor') do |field|
      # solr_parameters hash are sent to Solr as ordinary url query params.
      field.solr_parameters = { :"spellcheck.dictionary" => "contributor" }

      # :solr_local_parameters will be sent using Solr LocalParams
      # syntax, as eg {! qf=$title_qf }. This is neccesary to use
      # Solr parameter de-referencing like $title_qf.
      # See: http://wiki.apache.org/solr/LocalParams
      solr_name = solr_name("desc_metadata__contributor", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end



    config.add_search_field('creator') do |field|
      field.solr_parameters = { :"spellcheck.dictionary" => "creator" }
      solr_name = solr_name("desc_metadata__creator", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end

    config.add_search_field('title') do |field|
      field.solr_parameters = {
        :"spellcheck.dictionary" => "title"
      }
      solr_name = solr_name("desc_metadata__title", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end

    config.add_search_field('description') do |field|
      field.label = "Abstract or Summary"
      field.solr_parameters = {
        :"spellcheck.dictionary" => "description"
      }
      solr_name = solr_name("desc_metadata__description", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end

    config.add_search_field('publisher') do |field|
      field.solr_parameters = {
        :"spellcheck.dictionary" => "publisher"
      }
      solr_name = solr_name("desc_metadata__publisher", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end

    config.add_search_field('date_created') do |field|
      field.solr_parameters = {
        :"spellcheck.dictionary" => "date_created"
      }
      solr_name = solr_name("desc_metadata__created", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end

    config.add_search_field('subject') do |field|
      field.solr_parameters = {
        :"spellcheck.dictionary" => "subject"
      }
      solr_name = solr_name("desc_metadata__subject", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end

    config.add_search_field('language') do |field|
      field.solr_parameters = {
        :"spellcheck.dictionary" => "language"
      }
      solr_name = solr_name("desc_metadata__language", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end

    config.add_search_field('resource_type') do |field|
      field.solr_parameters = {
        :"spellcheck.dictionary" => "resource_type"
      }
      solr_name = solr_name("desc_metadata__resource_type", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end

    config.add_search_field('format') do |field|
      field.include_in_advanced_search = false
      field.solr_parameters = {
        :"spellcheck.dictionary" => "format"
      }
      solr_name = solr_name("desc_metadata__format", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end

    config.add_search_field('identifier') do |field|
      field.include_in_advanced_search = false
      field.solr_parameters = {
        :"spellcheck.dictionary" => "identifier"
      }
      solr_name = solr_name("desc_metadata__id", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end

    config.add_search_field('based_near') do |field|
      field.label = "Location"
      field.solr_parameters = {
        :"spellcheck.dictionary" => "based_near"
      }
      solr_name = solr_name("desc_metadata__based_near", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end

    config.add_search_field('tag') do |field|
      field.solr_parameters = {
        :"spellcheck.dictionary" => "tag"
      }
      solr_name = solr_name("desc_metadata__tag", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end

    config.add_search_field('depositor') do |field|
      solr_name = solr_name("desc_metadata__depositor", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end

    config.add_search_field('rights') do |field|
      solr_name = solr_name("desc_metadata__rights", :stored_searchable, type: :string)
      field.solr_local_parameters = {
        :qf => solr_name,
        :pf => solr_name
      }
    end


    # "sort results by" select (pulldown)
    # label in pulldown is followed by the name of the SOLR field to sort by and
    # whether the sort is ascending or descending (it must be asc or desc
    # except in the relevancy case).
    # label is key, solr field is value
    config.add_sort_field "#{title_field} asc", :label => "title \u25BC"
    config.add_sort_field "score desc, #{uploaded_field} desc", :label => "relevance \u25BC"
    config.add_sort_field "#{uploaded_field} desc", :label => "date uploaded \u25BC"
    config.add_sort_field "#{uploaded_field} asc", :label => "date uploaded \u25B2"
    config.add_sort_field "#{modified_field} desc", :label => "date modified \u25BC"
    config.add_sort_field "#{modified_field} asc", :label => "date modified \u25B2"

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

  def limit_to_scope(solr_parameters, user_parameters)
    # Do not bother constructing filter query if user is searching
    # from the graph root.
    return true if params[:scope] == Rails.application.config.root_community_id

    doc = fetch_solr_document(id: params[:scope])
    descendents = doc.combined_set_descendents

    # Limit query to items that are set descendents
    # or files off set descendents
    query = descendents.map do |set|
      p = set.pid
      set = "id:\"#{p}\" OR is_member_of_ssim:\"info:fedora/#{p}\""
    end

    # Ensure files directly on scoping collection are added in
    # as well
    query << "is_member_of_ssim:\"info:fedora/#{params[:scope]}\""

    fq = query.join(" OR ")

    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << fq
  end

  def limit_to_smart_search_scope(solr_parameters, user_parameters)
    doc = fetch_solr_document(id: params[:scope])
    descendents = doc.combined_set_descendents

    case params["smart_search"]
    when "employees"
      filter_klass = "Employee"
    when "research"
      filter_klass = "Research Publications"
    when "other"
      filter_klass = "Other Publications"
    when "presentations"
      filter_klass = "Presentations"
    when "datasets"
      filter_klass = "Datasets"
    when "learning"
      filter_klass = "Learning Objects"
    else
      raise "received #{params["smart_search"]} as smart search scope"
    end

    if filter_klass == "Employee"
      descendents = descendents.select { |x| x.klass == "Employee" }
      query = descendents.map do |set|
        set = "id:\"#{set.pid}\""
      end
    else
      descendents = descendents.select { |x| x.smart_collection_type == filter_klass }
      query = descendents.map do |set|
        set = "id:\"#{set.pid}\" OR is_member_of_ssim:\"info:fedora/#{set.pid}\""
      end
    end

    fq = query.join(" OR ")
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << fq
  end

  def featured_content_only(solr_parameters, user_parameters)
    categories = ["Theses and Dissertations", "Research Publications",
                  "Other Publications", "Presentations", "Datasets",
                  "Learning Objects"]

    query = categories.map { |x| "drs_category_ssim:\"#{x}\""}
    query = query.join(" OR ")

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
    query = "drs_category_ssim:\"Employee\""
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  def theses_and_dissertations_filter(solr_parameters, user_parameters)
    query = "drs_category_ssim:\"Theses and Dissertations\""
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  def no_incomplete_records(solr_parameters, user_parameters)
    query = "-in_progress_tesim:true"

    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  def full_text_search(solr_parameters, user_parameters)
    solr_parameters[:qf] ||= []
    solr_parameters[:qf] << " all_text_timv"
    solr_parameters[:hl] = "true"
  end
end
