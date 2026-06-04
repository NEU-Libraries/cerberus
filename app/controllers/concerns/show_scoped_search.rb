# frozen_string_literal: true

# Keeps Blacklight's facet / sort / per-page / pagination links scoped to
# a Community or Collection *show* page instead of escaping to the global
# catalog search.
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
# (Communities, Collections) rather than CatalogController itself, so the
# real catalog's facet links still target /catalog as they should.
module ShowScopedSearch
  extend ActiveSupport::Concern

  def search_action_url(options = {})
    options = options.to_h if options.is_a?(Blacklight::SearchState)

    # Fall back to Blacklight's default when there's no object to scope to
    # (defensive — these controllers only render the faceted sidebar on a
    # show page, which always has an :id).
    return super if params[:id].blank?

    url_for(options.reverse_merge(action: 'show', id: params[:id]))
  end
end
