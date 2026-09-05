# frozen_string_literal: true

class CatalogController < ApplicationController
  include Blacklight::Catalog

  self.search_state_class = SearchState

  configure_blacklight do |config|
    config.search_service_class = GatedSearchService
    config.view.gallery(document_component: Blacklight::Gallery::DocumentComponent, icon: Blacklight::Gallery::Icons::GalleryComponent)

    # The layout renders whatever this names and nothing else, so the DRS
    # header has to be reachable from here to appear at all.
    config.header_component = Cerberus::HeaderComponent

    # Facet panels are cards here, not Bootstrap accordion items — see the
    # Blacklight::Facets::FieldComponent template override.
    config.index.facet_group_component = Cerberus::FacetGroupComponent

    # Retain the genres `category` param in the search state. Blacklight's
    # permit_search_params strips any param not in search_state_fields, so without
    # this the view-type toggle (whose URL is url_for(search_state.to_h.merge(view:)))
    # drops `category` — landing on /genres?view=list with no genre, which renders
    # an empty category. (Pagination/search survive via GenresController#search_action_url,
    # which re-merges category; the toggle bypasses that.) Harmless elsewhere — no
    # other surface sets `category`.
    config.search_state_fields += %i[category]

    # config.track_search_session = false
    config.track_search_session.storage = false
    config.autocomplete_enabled = false
    config.autocomplete_path = nil

    # Blacklight ships an advanced search form at /catalog/advanced and enables
    # it by default. It is off here because the form enumerates every facet
    # field with no value limit, and several of ours are descriptive fields
    # whose value lists are unbounded. Turning it on is a deliberate piece of
    # work — curate which facets appear, and cap the ones that stay — not a
    # default to inherit.
    config.advanced_search.enabled = false
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
    # hl*: body-text highlighting for the "Full Text Match" snippet, over the
    # dedicated full_text_tsim field Atlas projects from extracted document text.
    # NOT all_text_timv — that is a catch-all (ACLs, NUIDs, ids, URLs) and would
    # leak internal data into snippets and match noise tokens.
    config.default_solr_params = {
      rows: 10, hl: true, 'hl.fl': 'full_text_tsim', 'hl.fragsize': 200,
      fq: ['-internal_resource_tesim:FileSet',
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
    # Both presenters differ from Blacklight's only in rendering a heading's
    # sub/sup markup. Set on config.index rather than per view because
    # view_config merges the named view over these defaults, so list and gallery
    # both inherit it.
    config.index.document_presenter_class = EnhancedIndexPresenter
    config.show.document_presenter_class = EnhancedShowPresenter
    # config.index.display_type_field = 'format'
    # config.index.thumbnail_field = 'thumbnail_path_ss'
    config.index.thumbnail_method = :iiif_thumbnail

    # Container browses — a community, collection, set or genre listing its
    # members — render a result list from a `show` action, so their rows are
    # built against config.show. Most of what they need falls through from
    # config.index, because a view config reverse-merges it. This key does not:
    # Blacklight sets it to nil on config.show so its own single-document page
    # draws no thumbnail, and a key that is present-but-nil blocks the merge.
    # Naming it here is what puts the thumbnail and its type pill back on every
    # container row.
    config.show.document_thumbnail_component = Blacklight::Document::ThumbnailComponent

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

    # Cerberus defined facets lead — Type first as the discovery anchor: it is
    # always populated for any search (Work/Collection/Community) and renders
    # open (collapse:false), so users always see a facet there to learn the
    # affordance. Content (the projected media classification) sits directly
    # beneath it. Both precede the descriptive-metadata facets below.
    config.add_facet_field 'type_ssim', label: 'Type', collapse: false
    # Content type (Image/Video/Text/Map/…) projected onto the Work from its
    # FileSets' Classification by Atlas's ClassificationIndexer. Multivalued —
    # a mixed-media Work surfaces under each of its formats; values are
    # display-ready Classification#name strings (no i18n mapping needed).
    config.add_facet_field 'classification_ssim', label: 'Content'
    # Genre / scholarly category (Research Publications, Presentations, Datasets,
    # Technical Reports, Monographs, Theses & Dissertations, …) projected onto the
    # Work from MODS <genre> by Atlas's GenreIndexer. Multivalued; values are the
    # genre strings as authored (no i18n mapping needed). Works only — empty for
    # Collections/Communities and for Works without a genre.
    config.add_facet_field 'genre_ssim', label: 'Genre'
    # No facet over MODS <typeOfResource>. Content above answers the same question
    # a reader is asking, in words they use: it offers Image / Video / Text /
    # Presentation where typeOfResource offers "still image" and "mixed material".
    # Two controls that sort results the same way, one of them worded worse, is a
    # cost with no return. Atlas still indexes resource_type_ssim.

    # Creator names in citation display form, projected onto the Work by Atlas's
    # CitationIndexer from the MODS names carrying a MARC creator relator.
    # Multivalued — a co-authored Work is browsable under each of its creators.
    config.add_facet_field 'creator_ssim', label: 'Creator', limit: 20, index_range: 'A'..'Z'
    config.add_facet_field 'pub_date_ssim', label: 'Publication Year', single: true
    # Topical subject and language, projected by Atlas's MODSIndexer for every
    # Modsable resource rather than for Works alone. subject_ssim carries MODS
    # <topic>, which is a wider set than the citation keywords GoogleScholarMetadata
    # reads off the same field.
    config.add_facet_field 'subject_ssim', label: 'Topic', limit: 20, index_range: 'A'..'Z'
    # The other four MODS subject axes, labelled as Atlas's WorkDecorator::DISPLAY
    # labels them so a facet and the metadata row beneath a result agree. Kept
    # apart rather than merged into Topic: a place, a period and a person are
    # different questions, and collapsing them buries the small axes under the
    # large one.
    #
    # Places carries MODS <subject><geographic> AND the narrowest level of a
    # <hierarchicalGeographic> — Atlas composes that down to "Parksville" rather
    # than indexing every level, since a continent every record shares would bury
    # the useful value.
    config.add_facet_field 'subject_geo_ssim', label: 'Places', limit: 20, index_range: 'A'..'Z'
    config.add_facet_field 'subject_era_ssim', label: 'Time periods', limit: true
    config.add_facet_field 'subject_person_ssim', label: 'People', limit: 20, index_range: 'A'..'Z'
    config.add_facet_field 'subject_corporate_ssim', label: 'Organizations', limit: 20, index_range: 'A'..'Z'

    # Origin, not subject. Place of publication is where the resource was
    # published; Places above is what it is *about*, and one record commonly
    # carries both with different values. The labels have to keep saying which
    # is which.
    #
    # Neither this nor Publisher is authority-controlled — MODS leaves both free
    # text — so near-duplicates ("Boston" and "Boston, Mass.") are two buckets.
    # Acceptable for narrowing a result set; it would not be for a primary browse.
    config.add_facet_field 'place_ssim', label: 'Place of publication', limit: true
    config.add_facet_field 'publisher_ssim', label: 'Publisher', limit: 20, index_range: 'A'..'Z'
    config.add_facet_field 'language_ssim', label: 'Language', limit: true

    # MODS <classification>, which in DRS holds IPTC photo categories rather than
    # the classification-scheme value the element is defined for: Iptc::MODSBuilder
    # maps the IPTC Category tag ('POR', 'HEA') to a label ('portraits',
    # 'headshots') on every photo ingest. Atlas names the Solr field for what it
    # holds; classification_ssim was unavailable, since that carries the FileSet
    # content vocabulary behind the Content facet above.
    #
    # A supplemental category is appended to the primary one, so a value can read
    # 'classroom -- engineering'. That is a compound bucket, not a hierarchy.
    config.add_facet_field 'photo_category_ssim', label: 'Photo category', limit: 20

    # Have BL send all facet field names to Solr, which has been the default
    # previously. Simply remove these lines if you'd rather use Solr request
    # handler defaults, or have no facets.
    config.add_facet_fields_to_solr_request!

    # solr fields to be displayed in the index (search results) view
    #   The ordering of the field names is the order of the display
    # Every multi-valued field here joins. MetadataFieldLayoutComponent emits one
    # <dt> and one <dd> per value into a Bootstrap `.row`, so a second <dd> wraps
    # onto a fresh flex line and the *next* field's <dt> fills the gap beside it —
    # a label rendered next to another field's value. Joining also spares each
    # value its own truncation toggle under one shared label.
    config.add_index_field 'creator_ssim', label: 'Creator', join: true
    config.add_index_field 'description_tsim', label: 'Description', join: true
    config.add_index_field 'language_ssim', label: 'Language', join: true

    # A container browse (a community, collection or set listing its members)
    # renders its member rows from the show config, not the index config, so
    # these two lists have to be kept in step. Blacklight's own single-document
    # show page is dead surface here — SolrDocument#to_param routes every
    # document link to Cerberus's own /works/:noid and friends.
    config.add_show_field 'creator_ssim', label: 'Creator', join: true
    config.add_show_field 'description_tsim', label: 'Description', join: true
    config.add_show_field 'language_ssim', label: 'Language', join: true

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
    #
    # Every clause must name a field Atlas indexes as single-valued: Solr sorts
    # on a single-valued field only, and it does not error on a field no
    # document carries — it finds the value missing everywhere and returns
    # index order, so a sort naming an unindexed field silently does nothing.
    # `title_ssi`, `creator_ssi` and `date_ssi` are Atlas's SortIndexer fields,
    # projected for sorting alone and never displayed; `created_at_dtsi` is
    # Valkyrie's own record timestamp. Title breaks each name tie so a sort is
    # deterministic across pages.
    #
    # date_ssi and created_at_dtsi are deliberately separate options: date_ssi
    # is the MODS origin date (when the thing itself was made), created_at_dtsi
    # is when the repository made the record. For an archival scan a reader
    # wants the first.
    config.add_sort_field 'relevance', sort: 'score desc, created_at_dtsi desc', label: 'relevance'
    config.add_sort_field 'title', sort: 'title_ssi asc', label: 'title'
    config.add_sort_field 'creator', sort: 'creator_ssi asc, title_ssi asc', label: 'creator (A-Z)'
    config.add_sort_field 'creator-desc', sort: 'creator_ssi desc, title_ssi asc', label: 'creator (Z-A)'
    config.add_sort_field 'date-created', sort: 'date_ssi desc, title_ssi asc', label: 'date created'
    config.add_sort_field 'date-added', sort: 'created_at_dtsi desc, title_ssi asc', label: 'date added'

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

  # Plumb the acting user into the search service. Blacklight 8 scopes every
  # SearchBuilder to the SearchService (not the controller), which exposes no
  # current_user/effective_user — so without this, SearchBuilder#gated_user is
  # nil and gated discovery silently collapses to public-only, ignoring group
  # membership and the admin short-circuit (across container/set contents and
  # the catalog index alike). `effective_user` honors a view-as session.
  def search_service_context
    { current_user: current_user, effective_user: effective_user,
      catalog_index: catalog_index? }
  end

  # The global catalog index (/catalog) — vs a scoped browse served by a
  # subclass show/index (communities, collections, genres, people). Only the
  # global index drops curation/structural containers — Featured showcases and
  # personal roots (see SearchBuilder#exclude_curation_containers); scoped
  # browses keep them.
  def catalog_index?
    controller_name == 'catalog' && action_name == 'index'
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
  # +exclude_uuids+ removes specific children from the result *at query time* (an
  # fq), so the response's documents AND its facet counts reflect the same set.
  # Used to hide empty Featured showcases from a community browse without leaving
  # the Type facet counting them (a Ruby post-filter on the documents would not
  # touch Solr's facets).
  def find_children(uuid, noid, exclude_uuids: [])
    return Blacklight::Solr::Response.new({}, {}) if uuid.blank?

    # Direct members (browse), or the whole subtree when a keyword query is active.
    membership = if params[:q].present?
                   subtree_membership_fq(uuid, noid)
                 else
                   MembershipQuery.members_fq([uuid], include_linked: true)
                 end
    filters = [membership]
    filters << MembershipQuery.excluding_fq(MembershipQuery.identity_fq(exclude_uuids)) if exclude_uuids.present?
    builder = search_service.search_builder.with(search_state).with_filters(*filters)
    Blacklight.default_index.search(params: builder)
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

    Blacklight.default_index.search(params: builder).documents.map(&:id)
  end

  # Type pill overlay — keeps the resource type legible even when a custom
  # thumbnail replaces the default type icon (mirrors v1). The pill is a sibling
  # of the thumbnail media (both inside .document-thumbnail, the positioning
  # context), so the media's img→fallback nextElementSibling onerror swap is
  # unaffected.
  def iiif_thumbnail(document, *_args)
    # Pill text via the shared helper (ApplicationHelper#pill_label owns the
    # priority order). Two states earn an opaque variant over the translucent gray
    # every other tile uses, because both are facts worth reading at a glance
    # rather than blending into the thumbnail.
    pill_class = ['thumb-type-pill', pill_state_class(document)].compact.join(' ')
    pill = view_context.content_tag(:span, view_context.pill_label(document), class: pill_class)
    view_context.safe_join([thumbnail_media(document), pill])
  end

  # Same precedence as the label, so the tone and the text never disagree.
  def pill_state_class(document)
    return 'thumb-type-pill--unfinished' if document.try(:in_progress?)
    return 'thumb-type-pill--embargoed' if document.try(:embargoed?)
    return 'thumb-type-pill--incomplete' if document.try(:incomplete?)

    nil
  end

  # The thumbnail image (with a hidden type-icon fallback for broken/missing
  # images) or, when there's no custom thumbnail, the type icon itself.
  def thumbnail_media(document)
    icon_class = helpers.document_type_icon(document.klass_type)
    icon_html  = view_context.content_tag(:i, '', class: "fa-solid #{icon_class} fa-2xl text-black-50")

    src = document.thumbnail_2x_ssi.presence || document.thumbnail_ssi
    return view_context.content_tag(:span, icon_html, class: 'thumbnail-fallback') if src.blank?

    fallback = view_context.content_tag(:span, icon_html, class: 'thumbnail-fallback d-none')
    img = view_context.image_tag(src,
                                 onerror: "this.classList.add('d-none'); \
                                           this.nextElementSibling.classList.remove('d-none');")
    view_context.content_tag(:span, img + fallback, class: 'thumbnail-wrapper')
  end

  helper_method :iiif_thumbnail if respond_to? :helper_method
end
