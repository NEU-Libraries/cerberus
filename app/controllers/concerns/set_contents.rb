# frozen_string_literal: true

# A Set's contents: the scoped search that lists them, and how they display.
# Include it after ShowScopedSearch, whose #facet_scope_filters this supplies.
module SetContents
  extend ActiveSupport::Concern

  included do
    # The contents are rows with a provenance rail and a Hide button, which a
    # gallery card has no place for, so the sidebar the Set page shares with the
    # catalog must not offer a gallery view. This edits the copy Blacklight
    # builds for the including class, never the catalog's own config.
    configure_blacklight do |config|
      config.view.delete(:gallery)
    end
  end

  private

    # The Set's resolved contents, which is what #show lists. load_set has
    # already fetched and authorized the Set itself, so a private Set refuses
    # here exactly as it refuses on the show page. A recipe with no positive
    # clause yields nil, and the modal renders empty rather than counting the
    # whole index.
    def facet_scope_filters
      @resolver = SetResolver.new(compilation: @set, search_service: search_service)
      @resolver.contents_fqs
    end

    # The recipe fq layered onto a state-seeded builder — find_children's
    # shape. A recipe with no positive clause renders empty (nil fq would
    # otherwise match the whole index).
    def contents_response
      fqs = @resolver.contents_fqs
      return Blacklight::Solr::Response.new({}, {}) if fqs.nil?

      builder = search_service.search_builder.with(search_state).with_filters(*fqs)
      Blacklight.default_index.search(params: builder)
    end
end
