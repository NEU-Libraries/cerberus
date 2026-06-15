# frozen_string_literal: true

class CatalogController < ApplicationController
  include Blacklight::Catalog

  self.search_state_class = SearchState

  configure_blacklight do |config|
    config.search_service_class = GatedSearchService
    config.view.gallery(document_component: Blacklight::Gallery::DocumentComponent, icon: Blacklight::Gallery::Icons::GalleryComponent)

    # config.track_search_session = false
    config.track_search_session.storage = false
    config.autocomplete_enabled = false
    config.autocomplete_path = nil
    ## Class for sending and receiving requests from a search index
    # config.repository_class = Blacklight::Solr::Repository
    #
    ## Class for converting Blacklight's url parameters to into request parameters for the search index
    # config.search_builder_class = ::SearchBuilder
    #
    ## Model that maps search index responses to the blacklight response model
    # config.response_model = Blacklight::Solr::Response
    #
    ## Should the raw solr document endpoint (e.g. /catalog/:id/raw) be enabled
    # config.raw_endpoint.enabled = false

    ## Default parameters to send to solr for all search-like requests. See also SearchBuilder#processed_parameters
    config.default_solr_params = {
      rows: 10,
      fq:   ['-internal_resource_tesim:FileSet',
             '-internal_resource_tesim:Blob',
             '-internal_resource_tesim:Delegate',
             '-tombstoned_bsi:true']
    }

    # solr path which will be added to solr base url before the other solr params.
    # config.solr_path = 'select'
    # config.document_solr_path = 'get'

    # items to show per page, each number in the array represent another option to choose from.
    # config.per_page = [10,20,50,100]

    # solr field configuration for search results/index views
    config.index.title_field = 'title_tsim'
    # config.index.display_type_field = 'format'
    # config.index.thumbnail_field = 'thumbnail_path_ss'
    config.index.thumbnail_method = :iiif_thumbnail

    # config.add_results_document_tool(:bookmark, partial: 'bookmark_control', if: :render_bookmarks_control?)
    config.index.document_actions.delete(:bookmark)
    config.show.document_actions.delete(:bookmark)
    config.navbar.partials.delete(:bookmark)

    config.add_results_collection_tool(:sort_widget)
    config.add_results_collection_tool(:per_page_widget)
    config.add_results_collection_tool(:view_type_group)

    # config.add_nav_action(:bookmark, partial: 'blacklight/nav/bookmark', if: :render_bookmarks_control?)
    # config.add_nav_action(:search_history, partial: 'blacklight/nav/search_history')

    # solr field configuration for document/show views
    # config.show.title_field = 'title_tsim'
    # config.show.display_type_field = 'format'
    # config.show.thumbnail_field = 'thumbnail_path_ss'

    # solr fields that will be treated as facets by the blacklight application
    #   The ordering of the field names is the order of the display
    #
    # Setting a limit will trigger Blacklight's 'more' facet values link.
    # * If left unset, then all facet values returned by solr will be displayed.
    # * If set to an integer, then "f.somefield.facet.limit" will be added to
    # solr request, with actual solr request being +1 your configured limit --
    # you configure the number of items you actually want _displayed_ in a page.
    # * If set to 'true', then no additional parameters will be sent to solr,
    # but any 'sniffed' request limit parameters will be used for paging, with
    # paging at requested limit -1. Can sniff from facet.limit or
    # f.specific_field.facet.limit solr request params. This 'true' config
    # can be used if you set limits in :default_solr_params, or as defaults
    # on the solr side in the request handler itself. Request handler defaults
    # sniffing requires solr requests to be made with "echoParams=all", for
    # app code to actually have it echo'd back to see it.
    #
    # :show may be set to false if you don't want the facet to be drawn in the
    # facet bar
    #
    # set :index_range to true if you want the facet pagination view to have facet
    #  prefix-based navigation
    #  (useful when user clicks "more" on a large facet and wants to navigate
    #  alphabetically across a large set of results)
    # :index_range can be an array or range of prefixes that will be used to
    #  create the navigation (note: It is case sensitive when searching values)

    config.add_facet_field 'format', label: 'Format'
    config.add_facet_field 'pub_date_ssim', label: 'Publication Year', single: true
    config.add_facet_field 'subject_ssim', label: 'Topic', limit: 20, index_range: 'A'..'Z'
    config.add_facet_field 'language_ssim', label: 'Language', limit: true
    config.add_facet_field 'lc_1letter_ssim', label: 'Call Number'
    config.add_facet_field 'subject_geo_ssim', label: 'Region'
    config.add_facet_field 'subject_era_ssim', label: 'Era'

    # Cerberus defined facets
    config.add_facet_field 'type_ssim', label: 'Type', collapse: false

    config.add_facet_field 'example_pivot_field', label: 'Pivot Field', pivot: %w[format language_ssim],
                                                  collapsing: true

    config.add_facet_field 'example_query_facet_field', label: 'Publish Date', query: {
      years_5:  { label: 'within 5 Years', fq: "pub_date_ssim:[#{Time.zone.now.year - 5} TO *]" },
      years_10: { label: 'within 10 Years', fq: "pub_date_ssim:[#{Time.zone.now.year - 10} TO *]" },
      years_25: { label: 'within 25 Years', fq: "pub_date_ssim:[#{Time.zone.now.year - 25} TO *]" }
    }

    # Have BL send all facet field names to Solr, which has been the default
    # previously. Simply remove these lines if you'd rather use Solr request
    # handler defaults, or have no facets.
    config.add_facet_fields_to_solr_request!

    # solr fields to be displayed in the index (search results) view
    #   The ordering of the field names is the order of the display
    # config.add_index_field 'title_tsim', label: 'Title'
    # config.add_index_field 'title_vern_ssim', label: 'Title'
    config.add_index_field 'author_tsim', label: 'Author'
    config.add_index_field 'author_vern_ssim', label: 'Author'
    config.add_index_field 'format', label: 'Format'
    config.add_index_field 'language_ssim', label: 'Language'
    config.add_index_field 'published_ssim', label: 'Published'
    config.add_index_field 'published_vern_ssim', label: 'Published'
    config.add_index_field 'lc_callnum_ssim', label: 'Call number'
    config.add_index_field 'description_tsim', label: 'Description'

    # solr fields to be displayed in the show (single result) view
    #   The ordering of the field names is the order of the display
    # config.add_show_field 'title_tsim', label: 'Title'
    # config.add_show_field 'title_vern_ssim', label: 'Title'
    config.add_show_field 'description_tsim', label: 'Description'
    config.add_show_field 'subtitle_tsim', label: 'Subtitle'
    config.add_show_field 'subtitle_vern_ssim', label: 'Subtitle'
    config.add_show_field 'author_tsim', label: 'Author'
    config.add_show_field 'author_vern_ssim', label: 'Author'
    config.add_show_field 'format', label: 'Format'
    config.add_show_field 'url_fulltext_ssim', label: 'URL'
    config.add_show_field 'url_suppl_ssim', label: 'More Information'
    config.add_show_field 'language_ssim', label: 'Language'
    config.add_show_field 'published_ssim', label: 'Published'
    config.add_show_field 'published_vern_ssim', label: 'Published'
    config.add_show_field 'lc_callnum_ssim', label: 'Call number'
    config.add_show_field 'isbn_ssim', label: 'ISBN'

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

    # This one uses all the defaults set by the solr request handler. Which
    # solr request handler? The one set in config[:default_solr_parameters][:qt],
    # since we aren't specifying it otherwise.

    config.add_search_field 'all_fields', label: 'All Fields'

    # Now we see how to over-ride Solr request handler defaults, in this
    # case for a BL "search field", which is really a dismax aggregate
    # of Solr search fields.

    # config.add_search_field('title') do |field|
    #   # solr_parameters hash are sent to Solr as ordinary url query params.
    #   field.solr_parameters = {
    #     'spellcheck.dictionary': 'title',
    #     qf: '${title_qf}',
    #     pf: '${title_pf}'
    #   }
    # end

    # config.add_search_field('author') do |field|
    #   field.solr_parameters = {
    #     'spellcheck.dictionary': 'author',
    #     qf: '${author_qf}',
    #     pf: '${author_pf}'
    #   }
    # end

    # Specifying a :qt only to show it's possible, and so our internal automated
    # tests can test it. In this case it's the same as
    # config[:default_solr_parameters][:qt], so isn't actually neccesary.
    # config.add_search_field('subject') do |field|
    #   field.qt = 'search'
    #   field.solr_parameters = {
    #     'spellcheck.dictionary': 'subject',
    #     qf: '${subject_qf}',
    #     pf: '${subject_pf}'
    #   }
    # end

    # "sort results by" select (pulldown)
    # label in pulldown is followed by the name of the Solr field to sort by and
    # whether the sort is ascending or descending (it must be asc or desc
    # except in the relevancy case). Add the sort: option to configure a
    # custom Blacklight url parameter value separate from the Solr sort fields.
    config.add_sort_field 'relevance', sort: 'score desc, pub_date_si desc, title_si asc', label: 'relevance'
    config.add_sort_field 'year-desc', sort: 'pub_date_si desc, title_si asc', label: 'year'
    config.add_sort_field 'author', sort: 'author_si asc, title_si asc', label: 'author'
    config.add_sort_field 'title_si asc, pub_date_si desc', label: 'title'

    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 5

    # Configuration for autocomplete suggester
    # config.autocomplete_enabled = true
    # config.autocomplete_path = 'suggest'
    # if the name of the solr.SuggestComponent provided in your solrconfig.xml is not the
    # default 'mySuggester', uncomment and provide it below
    # config.autocomplete_suggester = 'mySuggester'
  end

  # Children listing for a Community/Collection show page.
  #
  # Two modes, switched on whether a keyword query is active:
  #
  # * No query (plain browse, or facets only) — list the anchor's *direct*
  #   members, so the show page is a single tier of the tree. Facets narrow
  #   that tier; they do not deepen the scope.
  # * Keyword query present — search the whole *subtree* beneath the anchor
  #   (see #subtree_membership_fq), so a "Search this collection" query reaches
  #   Works and sub-collections nested arbitrarily deep, not just direct
  #   children.
  #
  # Either way the current search state (q, facets, sort, per_page, page) is
  # seeded onto the builder before the membership filter is layered on —
  # passing `with({})` would silently discard the user's query. The file-level
  # / tombstone type exclusions are not repeated here: they live in
  # config.default_solr_params, which Blacklight's processor chain seeds onto
  # the :fq of every search-like query (this one included).
  #
  # @param uuid [String] the anchor's valkyrie_id (uuid), as stored in the
  #   structural membership field.
  # @param noid [String] the anchor's bare noid, as stored in the descendants'
  #   ancestor chain. Only consulted in subtree mode.
  def find_children(uuid, noid)
    return Blacklight::Solr::Response.new({}, {}) if uuid.blank?

    membership = if params[:q].present?
                   subtree_membership_fq(uuid, noid)
                 else
                   MembershipQuery.members_fq([uuid], include_linked: true)
                 end

    builder = search_service.search_builder
                            .with(search_state)
                            .with_filters(membership)

    Blacklight.default_index.search(builder)
  end

  # fq matching everything in the anchor's subtree: every descendant
  # Collection/Community (so a query can hit a sub-collection by its own
  # metadata) OR every Work that is a member of — or linked into — the anchor or
  # any of its descendant containers.
  #
  # Uses the two-step reverse-ancestry recipe — resolve the descendant
  # containers, then match their members — but this variant returns the matching
  # containers themselves *and* threads the live search state through (via the
  # caller's `.with(search_state)`), which is why it's a bespoke query here
  # rather than a shared service.
  def subtree_membership_fq(anchor_uuid, anchor_noid)
    member_of = [anchor_uuid, *descendant_container_uuids(anchor_noid)]
    # One FLAT {!bool}: the descendant-containers clause OR each membership
    # clause (structural + linked). Nesting members_fq's own {!bool} inside a
    # quoted should= breaks Solr's parser, so splice the raw clauses instead.
    MembershipQuery.any_of(
      [MembershipQuery.descendants_fq(anchor_noid),
       *MembershipQuery.member_clauses(member_of, include_linked: true)]
    )
  end

  # uuids of every descendant Collection/Community of the anchor. Deliberately
  # query-agnostic (`with({})`): the full container set is needed to scope the
  # Works clause, regardless of the keyword the user typed. `rows` is lifted off
  # the default page size so a deep tree isn't silently truncated to one page,
  # and `fl` is trimmed to the id since that's all we read.
  def descendant_container_uuids(anchor_noid)
    builder = search_service.search_builder.with({}).with_filters(
      MembershipQuery.descendants_fq(anchor_noid),
      'internal_resource_tesim:(Collection OR Community)'
    ).merge(rows: 100_000, fl: 'id')

    Blacklight.default_index.search(builder).documents.map(&:id)
  end

  def iiif_thumbnail(document, *_args)
    icon_class = helpers.document_type_icon(document.klass_type)
    icon_html  = view_context.content_tag(:i, '', class: "fa-regular #{icon_class} fa-2xl text-black-50")

    src = document.thumbnail_2x_ssi.presence || document.thumbnail_ssi
    if src.present?
      fallback = view_context.content_tag(:span, icon_html,
                                          class: 'thumbnail-fallback d-none')
      img = view_context.image_tag(src,
                                   onerror: "this.classList.add('d-none'); \
                                             this.nextElementSibling.classList.remove('d-none');")
      view_context.content_tag(:span, img + fallback, class: 'thumbnail-wrapper')
    else
      view_context.content_tag(:span, icon_html, class: 'thumbnail-fallback')
    end
  end

  helper_method :iiif_thumbnail if respond_to? :helper_method
end
