# frozen_string_literal: true

# Lists every tombstoned (withdrawn) top-level resource — Works, Collections
# and Communities — for the admin restore registry. The companion of the
# tombstone actions on the show pages: those withdraw, this finds what was
# withdrawn so an admin can reverse it.
#
# Uses the same `Blacklight.default_index.search(builder)` idiom as the other
# Solr service objects (see ResourceSearch), but through {TombstonedSearchBuilder},
# which inverts the catalog's default `-tombstoned_bsi:true` exclusion. Paginated
# (withdrawals are rare, but the result rides Blacklight's Kaminari integration
# so the registry never dumps an unbounded list).
class TombstonedItems < ApplicationService
  PER_PAGE = 50

  # @param scope [#blacklight_config, #current_user] the admin controller; supplies
  #   the Blacklight config (copied from CatalogController) and the acting user
  #   that gated discovery reads (admins short-circuit it, seeing every resource).
  # @param page [Integer, String, nil] 1-based page number.
  def initialize(scope:, page: nil)
    @scope = scope
    @page = page
    super()
  end

  # @return [Blacklight::Solr::Response] the tombstoned resource documents,
  #   ordered by title (no withdrawal timestamp is indexed to sort on).
  def call
    builder = TombstonedSearchBuilder.new(@scope)
                                     .with(q: '*:*', per_page: PER_PAGE, page: @page)
                                     .merge(sort: 'title_si asc')
    Blacklight.default_index.search(builder)
  end
end
