# frozen_string_literal: true

# Lists the Works in one fixity state, for the admin fixity report. Solr rather
# than Atlas, for the same reason as StuckDeposits: a list surface wants titles,
# ordering and paging, which the Solr document already gives. See
# docs/fixity.md.
class FixityReport < ApplicationService
  PER_PAGE = 50

  # Overdue lists the longest unverified first, which is the order a sweep
  # would take them in. The other two lists have no check date to order by.
  SORTS = {
    failed:  'updated_at_dtsi desc',
    overdue: 'work_fixity_checked_at_dtsi asc',
    never:   'updated_at_dtsi desc'
  }.freeze

  # @param scope [#blacklight_config, #current_user] the admin controller.
  # @param state [Symbol] a key of FixitySearchBuilder::STATES.
  # @param page [Integer, String, nil] 1-based page number.
  def initialize(scope:, state:, page: nil)
    @scope = scope
    @state = state
    @page = page
    super()
  end

  # @return [Blacklight::Solr::Response]
  def call
    builder = FixitySearchBuilder.new(@scope)
                                 .with(q: '*:*', per_page: PER_PAGE, page: @page)
                                 .state(@state)
                                 .merge(sort: SORTS.fetch(@state))
    Blacklight.default_index.search(params: builder)
  end
end
