# frozen_string_literal: true

# Lists the Works stuck in one of two states, for the admin triage registry.
#
# Solr rather than Atlas's `GET /works?in_progress=true`. Both answer the same
# question, but this is a list surface: it wants titles, depositors, dates,
# ordering and Kaminari paging, which the Solr document and Blacklight already
# give — the same reason every other admin registry here reads Solr. Atlas's
# operator filter remains the right tool for a script.
class StuckDeposits < ApplicationService
  PER_PAGE = 50

  # @param scope [#blacklight_config, #current_user] the admin controller.
  # @param state [Symbol] :unconfirmed or :incomplete — see
  #   DepositTriageSearchBuilder::STATES.
  # @param page [Integer, String, nil] 1-based page number.
  def initialize(scope:, state:, page: nil)
    @scope = scope
    @state = state
    @page = page
    super()
  end

  # @return [Blacklight::Solr::Response] newest first, which is when a stuck
  #   deposit is cheapest to unstick: the depositor still remembers it and can be
  #   asked, where a year-old one needs a decision instead of a nudge. It also
  #   matches the tombstone registry and the ledger, so a reader moving between the
  #   admin registries does not have to relearn which end is which. The oldest are
  #   still there, at the back.
  def call
    builder = DepositTriageSearchBuilder.new(@scope)
                                        .with(q: '*:*', per_page: PER_PAGE, page: @page)
                                        .state(@state)
                                        .merge(sort: 'updated_at_dtsi desc')
    Blacklight.default_index.search(builder)
  end
end
