# frozen_string_literal: true

# Keeps Blacklight's facet / sort / per-page / pagination links scoped to
# a Community, Collection or Set *show* page instead of escaping to the global
# catalog search, and serves the facet "more" modal over the same scope.
#
# Blacklight::Catalog#search_action_url routes those links to the
# controller's :index action (the general catalog search), and
# add_facet_params_and_redirect drops the :id. On a show page that embeds
# a faceted search of the object's children, the result is a link like
# /communities?f[...] -> communities#index -> the inherited CatalogController
# search action, kicking the user out to /catalog. Re-point the links back
# at the current :show action (with its :id) so the embedded search stays
# in place.
#
# This is intentionally scoped to the controllers that mix it in
# (Communities, Collections, Sets) rather than CatalogController itself, so the
# real catalog's facet links still target /catalog as they should.
#
# Every includer must supply #facet_scope_filters. See docs/discovery.md.
module ShowScopedSearch
  extend ActiveSupport::Concern

  included do
    # Blacklight ships search_facet_path in a helper *module*. A method defined
    # on the controller's own _helpers module shadows one from an included
    # module, so helper_method is what lets the override below win.
    helper_method :search_facet_path, :facet_suggest_context
  end

  def search_action_url(options = {})
    options = options.to_h if options.is_a?(Blacklight::SearchState)

    # Fall back to Blacklight's default when there's no object to scope to
    # (defensive — these controllers only render the faceted sidebar on a
    # show page, which always has an :id).
    return super if params[:id].blank?

    url_for(options.reverse_merge(action: 'show', id: params[:id]))
  end

  # Blacklight's own helper builds `action: "facet"` on the current controller
  # and hands the facet key over as :id. On a show page :id already names the
  # container, so the key overwrites it: the container is lost and no route
  # matches, which takes the whole page down rather than just the link. Point
  # the link at the scoped route instead, which carries the container in :id and
  # the facet key in :facet_field.
  def search_facet_path(options = {})
    # These controllers also serve an :index — /collections, /communities — which
    # renders the same sidebar with no container to scope to. There is no modal
    # for an unscoped listing, and building one would put a nil in the :id
    # segment and raise. nil is what FacetFieldPresenter#modal_path wants for
    # "render no link".
    return if params[:id].blank?

    opts = search_state.to_h.merge(only_path: true).merge(options).except(:page)
    facet_field = opts.delete(:id)

    url_for(opts.merge(action: 'facet', id: params[:id], facet_field: facet_field))
  end

  # The scoped equivalent of Blacklight::Catalog#facet: the "more" modal for one
  # facet, counted over this container's contents rather than the whole index.
  def facet
    load_scoped_facet!

    # The modal fetches this over XHR and splices the fragment in; the bare
    # route is the no-JavaScript fallback and wants the full page.
    return render 'catalog/facet', layout: false if request.xhr?

    render 'catalog/facet'
  end

  # The type-ahead behind the modal's filter box: the same scoped counts as
  # #facet, narrowed by the typed fragment, rendered as the values list alone
  # because the JS swaps that into the modal already on screen.
  def facet_suggest
    # The container rides the query string here rather than the path, so unlike
    # #facet the router cannot vouch for it. Without this the includers'
    # facet_scope_filters resolve a nil id and fail well below the controller.
    raise ActionController::RoutingError, 'Not Found' if params[:id].blank?

    load_scoped_facet!(query_fragment: params[:query_fragment])

    render 'catalog/facet_values', layout: false
  end

  # The search context Blacklight's suggest JS reads off the input. It rebuilds
  # the fetch URL as `/<first path segment>/facet_suggest/<key>` plus this URL's
  # query string, so the context has to BE the suggest route: the container
  # survives only because ?id= is a query param, and the path it is dropped from
  # is one this route does not have. Anything moved into the path here is lost.
  def facet_suggest_context(key)
    return if params[:id].blank?

    opts = search_state.to_h.merge(only_path: true).except(:page)
    url_for(opts.merge(action: 'facet_suggest', facet_field: key, id: params[:id]))
  end

  private

    # Everything both facet actions render from. Kept together because the
    # authorization lives in facet_scope_filters: a caller who may not read the
    # container must not reach the counts by either route.
    def load_scoped_facet!(query_fragment: nil)
      filters = facet_scope_filters
      @facet = scoped_facet_config(params[:facet_field])
      raise ActionController::RoutingError, 'Not Found' if @facet.nil?

      @response = scoped_facet_response(@facet.key, filters, query_fragment)
      @display_facet = @response.aggregations[@facet.field]
      @presenter = @facet.presenter.new(@facet, @display_facet, view_context)
      @pagination = @presenter.paginator
    end

    # The fqs bounding this page's contents, or nil when the page denotes
    # nothing. Each includer implements it, and is also responsible for loading
    # and authorizing the container: these counts describe its contents, so they
    # must be gated exactly as its show page is.
    def facet_scope_filters
      raise NotImplementedError
    end

    # find_children's builder shape, narrowed to one facet.
    # SearchService#facet_field_response cannot stand in: it offers only an
    # extra-params merge, and a merged :fq replaces the gated-discovery clause
    # the builder already assembled rather than adding to it. Use with_filters.
    def scoped_facet_response(key, filters, query_fragment = nil)
      return Blacklight::Solr::Response.new({}, {}) if filters.nil?

      builder = search_service.search_builder
                              .with(search_state)
                              .with_filters(*filters)
                              .facet(key)
      # facet.contains, applied by the builder's own suggestion step. Blank is
      # not the same as absent: an empty fragment must count everything, which
      # is what the modal shows before anyone types.
      builder = builder.facet_suggestion_query(query_fragment) if query_fragment.present?
      Blacklight.default_index.search(params: builder)
    end

    # A per-request copy of this facet's config. Duplicated rather than used in
    # place because the modal renders from the shared blacklight_config, and any
    # per-request adjustment made to it would leak into every later request the
    # process serves.
    def scoped_facet_config(key)
      config = blacklight_config.facet_fields[key]
      return if config.nil?

      config.deep_dup
    end
end
