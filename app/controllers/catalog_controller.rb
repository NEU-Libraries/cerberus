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
  include BlacklightOaiProvider::ControllerExtension
  include SetListsHelper

  before_filter :default_search, except: [:facet, :recent]

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
      format.any { render_404(ActiveFedora::ObjectNotFoundError.new, request.fullpath) }
    end
  end

  def index
    if !has_search_parameters?
      self.solr_search_params_logic += [:disable_highlighting]
      recent

      # If user has multiple accounts, and no preferred account, send flash
      if current_user
        if current_user.multiple_accounts && current_user.account_pref.blank?
          flash[:notice] = "#{t('drs.multiple_accounts.login_alert')} Please visit your #{ActionController::Base.helpers.link_to("Accounts", select_account_path)} page to select a primary account."
        end
      else
        flash[:info] = "<a href='#{new_user_session_path}'>Sign in</a> with your myNEU username and password to see more content."
      end
    else
      begin
        if params[:format] == "rss"
          params[:per_page] = 10
          self.solr_search_params_logic += [:limit_to_public]
        else
          self.solr_search_params_logic += [:apply_per_page_limit]
        end

        super
      rescue Net::ReadTimeout
        self.solr_search_params_logic += [:disable_highlighting]
        super
      end
    end
  end

  def facet
    self.solr_search_params_logic += [:increase_facet_limit]
    # Kludgey kludge kludge
    params[:solr_field] = params[:id]
    # Put in logic handling the smart collections
    if params[:smart_collection]
      params.delete(:id)
      filter_name = "#{params[:smart_collection].to_s}_filter"
      self.solr_search_params_logic += [filter_name.to_sym]
      (_, @document_list) = get_search_results
      @pagination = get_facet_pagination(params[:solr_field], params)
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
  end

  def oai
    self.solr_search_params_logic += [:exclude_unwanted_models]
    # Due to errors or poor metadata in Fedora, we need to check for title
    self.solr_search_params_logic += [:well_formed_items]
    self.solr_search_params_logic += [:limit_to_public]
    super
  end

  def communities
    self.solr_search_params_logic += [:communities_filter]
    self.solr_search_params_logic += [:apply_per_page_limit]
    (@response, @document_list) = get_search_results
    render 'shared/smart_collections/smart_collection', locals: { smart_collection: 'communities' }
  end

  def research
    self.solr_search_params_logic += [:research_filter]
    self.solr_search_params_logic += [:apply_per_page_limit]
    (@response, @document_list) = get_search_results
    render 'shared/smart_collections/smart_collection', locals: { smart_collection: 'research' }
  end

  def presentations
    self.solr_search_params_logic += [:presentations_filter]
    self.solr_search_params_logic += [:apply_per_page_limit]
    (@response, @document_list) = get_search_results
    render 'shared/smart_collections/smart_collection', locals: { smart_collection: 'presentations' }
  end

  def datasets
    self.solr_search_params_logic += [:datasets_filter]
    self.solr_search_params_logic += [:apply_per_page_limit]
    (@response, @document_list) = get_search_results
    render 'shared/smart_collections/smart_collection', locals: { smart_collection: 'datasets' }
  end

  def technical_reports
    self.solr_search_params_logic += [:technical_reports_filter]
    self.solr_search_params_logic += [:apply_per_page_limit]
    (@response, @document_list) = get_search_results
    render 'shared/smart_collections/smart_collection', locals: { smart_collection: 'technical_reports' }
  end

  def monographs
    self.solr_search_params_logic += [:monographs_filter]
    self.solr_search_params_logic += [:apply_per_page_limit]
    (@response, @document_list) = get_search_results
    render 'shared/smart_collections/smart_collection', locals: { smart_collection: 'monographs' }
  end

  def faculty_and_staff
    self.solr_search_params_logic += [:faculty_and_staff_filter]
    self.solr_search_params_logic += [:apply_per_page_limit]
    (@response, @document_list) = get_search_results
    render 'shared/smart_collections/smart_collection', locals: { smart_collection: 'employees' }
  end

  def theses_and_dissertations
    self.solr_search_params_logic += [:theses_and_dissertations_filter]
    self.solr_search_params_logic += [:apply_per_page_limit]
    (@response, @document_list) = get_search_results
    render 'shared/smart_collections/smart_collection', locals: { smart_collection: 'theses_and_dissertations' }
  end

  def self.uploaded_field
    solr_name('system_create', :stored_sortable, type: :date)
  end

  def self.created_field
    solr_name('date', :stored_sortable, type: :string)
  end

  def self.title_field
    solr_name('title', :stored_sortable, type: :string)
  end

  def self.creator_field
    solr_name('creator', :stored_sortable, type: :string)
  end

  configure_blacklight do |config|
    config.oai = {
      :provider => {
        :repository_name => 'Cerberus',
        :repository_url => 'https://repository.library.northeastern.edu',
        :record_prefix => '',
        :admin_email => 'sj.sweeney@neu.edu'
      },
      :document => {
        :timestamp => 'timestamp',
        :limit => 25
      }
    }

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

    # NIEC
    # Speaker Gender = niec_gender_ssim
    config.add_facet_field solr_name("niec_gender", :symbol), label: "Speaker Gender", limit: true
    # Speaker Age = niec_age_ssim
    config.add_facet_field solr_name("niec_age", :symbol), label: "Speaker Age", limit: true
    # Speaker Race = niec_race_ssim
    config.add_facet_field solr_name("niec_race", :symbol), label: "Speaker Race", limit: true
    # Pace = niec_sign_pace_ssim
    config.add_facet_field solr_name("niec_sign_pace", :symbol), label: "Pace", limit: true
    # Fingerspelling Extent = niec_fingerspelling_extent_ssim
    config.add_facet_field solr_name("niec_fingerspelling_extent", :symbol), label: "Fingerspelling Extent", limit: true
    # Fingerspelling Pace = niec_fingerspelling_pace_ssim
    config.add_facet_field solr_name("niec_fingerspelling_pace", :symbol), label: "Fingerspelling Pace", limit: true
    # Numbers Pace = niec_numbers_pace_ssim
    config.add_facet_field solr_name("niec_numbers_pace", :symbol), label: "Numbers Pace", limit: true
    # Numbers Extent = niec_numbers_extent_ssim
    config.add_facet_field solr_name("niec_numbers_extent", :symbol), label: "Numbers Extent", limit: true
    # Classifiers Extent = niec_classifiers_extent_ssim
    config.add_facet_field solr_name("niec_classifiers_extent", :symbol), label: "Classifiers Extent", limit: true
    # Use of Space Extent = niec_use_of_space_extent_ssim
    config.add_facet_field solr_name("niec_use_of_space_extent", :symbol), label: "Use of Space Extent", limit: true
    # Use of Space = niec_how_space_used_ssim
    config.add_facet_field solr_name("niec_how_space_used", :symbol), label: "Use of Space", limit: true
    # Type of Text = niec_text_type_ssim
    config.add_facet_field solr_name("niec_text_type", :symbol), label: "Type of Text", limit: true
    # Register = niec_register_ssim
    config.add_facet_field solr_name("niec_register", :symbol), label: "Register", limit: true
    # Conversation Type = niec_conversation_type_ssim
    config.add_facet_field solr_name("niec_conversation_type", :symbol), label: "Conversation Type", limit: true
    # Audience = niec_audience_ssim
    config.add_facet_field solr_name("niec_audience", :symbol), label: "Audience", limit: true
    # Language = niec_signed_language_ssim
    config.add_facet_field solr_name("niec_signed_language", :symbol), label: "Language", limit: true
    # Spoken Language = niec_spoken_language_ssim
    config.add_facet_field solr_name("niec_spoken_language", :symbol), label: "Spoken Language", limit: true
    # Lends Itself to Classifiers = niec_lends_itself_to_classifiers_ssim
    config.add_facet_field solr_name("niec_lends_itself_to_classifiers", :symbol), label: "Lends Itself to Classifiers Use", limit: true
    # Lends Itself to Space = niec_lends_itself_to_use_of_space_ssim
    config.add_facet_field solr_name("niec_lends_itself_to_use_of_space", :symbol), label: "Lends Itself to Space Use", limit: true

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
    config.add_sort_field "#{uploaded_field} desc", :label => "Recently uploaded"
    config.add_sort_field "#{created_field} desc", :label => "Recently created"
    config.add_sort_field "score desc, #{uploaded_field} desc", :label => "Relevance"

    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 5
  end

  protected

  def default_search
    if !params[:q].nil?
      # Fixes #667 - we remove single characters. They're a pretty terrible idea with a strict AND
      params[:q].gsub!(/(^| ).( |$)/, ' ')

      if params[:sort].blank?
        # Default sort relevance
        params[:sort] = "score desc, #{Solrizer.solr_name('system_create', :stored_sortable, type: :date)} desc"
      end
    end
  end

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

  def limit_to_public(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "read_access_group_ssim:\"public\""
    solr_parameters[:fq] << "-in_progress_tesim:true OR -incomplete_tesim:true"
    solr_parameters[:fq] << "-embargo_release_date_dtsi:[* TO *]"
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

  def technical_reports_filter(solr_parameters, user_parameters)
    query = "drs_category_ssim:\"Technical Reports\""
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
    query = "-in_progress_tesim:true OR -incomplete_tesim:true OR -smart_collection_type_tesim:\"User Root\""

    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  def disable_highlighting(solr_parameters, user_parameters)
    solr_parameters[:hl] = "false"
  end

  def increase_facet_limit(solr_parameters, user_parameters)
    solr_parameters["facet.limit"] = "12"
  end

  def oai_time_filters(solr_parameters, user_parameters)
    if params.has_key?(:from) && params.has_key?(:until)
      solr_parameters[:fq] << "timestamp:[" + params[:from] + " TO " + params[:until] + "]"
    elsif params.has_key?(:from)
      solr_parameters[:fq] << "timestamp:[" + params[:from] + " TO NOW]"
    elsif params.has_key?(:until)
      solr_parameters[:fq] << "timestamp:[" + Time.at(0).utc.xmlschema + " TO " + params[:until]+ "]"
    end
  end

  def oai_set_filter(solr_parameters, user_parameters)
    comp = Compilation.find("neu:#{params[:set]}")
    pids = comp.entry_ids

    query = pids.map do |pid|
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
end
