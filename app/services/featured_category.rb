# frozen_string_literal: true

# The curated "Featured Content" view for one scholarly category — the homepage
# gateway / genre-landing destination. Unlike the catalog's genre_ssim facet
# (which reads each work's MODS <genre>), Featured Content is *curated*: it is
# the set of works deliberately published into a genre showcase. So this
# resolves every featured showcase Collection titled like the category (across
# all communities) and returns the works that are linked-members of them.
#
# Mirrors the gated `Blacklight.default_index.search(SearchBuilder.new(scope))`
# idiom of ResourceSearch / ShowcaseFinder; scope = the controller (current_user
# for gated discovery). search_state threads live q / facets / sort / page so the
# landing is browsable and search-within stays on the surface.
class FeaturedCategory < ApplicationService
  MAX_SHOWCASES = 500

  def initialize(scope:, label:, search_state: nil)
    @scope = scope
    @label = label.to_s
    @search_state = search_state
    super()
  end

  # @return [Blacklight::Solr::Response] the published works in this category
  #   (empty when the category names no showcase or none has members).
  def call
    return empty_response if @label.blank?

    uuids = showcase_uuids
    return empty_response if uuids.empty?

    works_in(uuids)
  end

  private

    # Solr uniqueKeys (uuids) of every featured Collection whose title is exactly
    # the category label. The title_tsim phrase narrows server-side; the Ruby
    # exact-match guards against a tokenized phrase over-matching ("Datasets" vs
    # "Datasets Annual").
    def showcase_uuids
      builder = SearchBuilder.new(@scope).with({}).with_filters(
        'internal_resource_tesim:Collection', 'featured_bsi:true', '-tombstoned_bsi:true',
        %(title_tsim:"#{@label.gsub(/["\\]/, '')}")
      ).merge(rows: MAX_SHOWCASES)
      Blacklight.default_index.search(builder).documents
                .select { |doc| Array(doc['title_tsim']).first == @label }
                .map(&:id)
    end

    # Works that are members of (structural or linked into) any of the showcases.
    def works_in(uuids)
      builder = SearchBuilder.new(@scope)
                             .with(@search_state || {})
                             .with_filters('internal_resource_tesim:Work', '-tombstoned_bsi:true',
                                           MembershipQuery.members_fq(uuids, include_linked: true))
      Blacklight.default_index.search(builder)
    end

    def empty_response
      Blacklight::Solr::Response.new({}, {})
    end
end
