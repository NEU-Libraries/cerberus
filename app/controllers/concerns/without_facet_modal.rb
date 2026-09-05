# frozen_string_literal: true

# Surfaces that embed the facet sidebar but own no `facet` route.
#
# Blacklight builds the sidebar's "See more" link by generating a URL for the
# `facet` action on the *current* controller. With no such route that raises
# UrlGenerationError from inside the view, taking the whole page down — not just
# the link — the moment any facet holds more values than
# config.default_facet_limit. Returning nil is the supported off switch:
# FacetFieldPresenter#modal_path passes it straight through, and the field
# component renders no link when modal_path is nil.
#
# Contrast ShowScopedSearch, which gives Collections, Communities and Sets a
# real scoped modal instead. See docs/discovery.md.
module WithoutFacetModal
  extend ActiveSupport::Concern

  included do
    helper_method :search_facet_path
  end

  def search_facet_path(*)
    nil
  end
end
