# frozen_string_literal: true

# Home / static pages. Inherits CatalogController (like GenresController,
# PeopleController and CommunitiesController) to obtain the gated `search_service`
# and inherited `search_service_context`, so the homepage "Recently Added Items"
# query is scoped to what the current visitor — guest or signed-in — may discover.
class PagesController < CatalogController
  # How many recently-added Works the homepage surfaces — one full four-up row of
  # gallery cards across the page width below the Featured Content bar.
  HOME_RECENT_COUNT = 4

  def home
    @recent_documents = recently_added_works
  end

  private

    # The most recently created Works the current user can discover, newest first.
    # Built on the gated search_builder so discovery permissions and the default
    # curation-container exclusion (featured / personal-root) apply automatically.
    # `with_filters` adds the Works-only clause — NOT `merge(fq:)`, which would
    # replace the whole fq array and silently drop the gated-discovery clause (see
    # SearchBuilder#with_filters). `created_at_dtsi` is Valkyrie's stable creation
    # timestamp (the reindex-volatile `timestamp` field is deliberately avoided).
    def recently_added_works
      builder = search_service.search_builder
                              .with({})
                              .with_filters('internal_resource_tesim:Work')
                              .merge(sort: 'created_at_dtsi desc', rows: HOME_RECENT_COUNT)
      Blacklight.default_index.search(builder).documents
    end
end
