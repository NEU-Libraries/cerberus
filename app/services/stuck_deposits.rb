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

  # @return [Blacklight::Solr::Response] oldest first. A triage list is worked
  #   from the back: the deposit stuck longest is the one most likely to have been
  #   forgotten, and the one that has been broken for an hour can wait.
  def call
    builder = DepositTriageSearchBuilder.new(@scope)
                                        .with(q: '*:*', per_page: PER_PAGE, page: @page)
                                        .state(@state)
                                        .merge(sort: 'updated_at_dtsi asc')
    Blacklight.default_index.search(builder)
  end
end
