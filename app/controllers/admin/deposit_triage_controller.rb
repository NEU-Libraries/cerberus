# frozen_string_literal: true

module Admin
  # Triage for deposits that got stuck, in the two ways they can.
  #
  # **Waiting on a depositor** — the Work is `in_progress`: nobody confirmed the
  # metadata page, so it is hidden from discovery and its depositor sees it under
  # "Deposits to finish" in My DRS. Somebody has to finish it or withdraw it.
  #
  # **Missing something** — the Work finished, but an enrichment job gave up, so it
  # is readable while short a rendition, a thumbnail or its full text. Only staff
  # can repair one, which is why this list exists at all: before it, the sole trace
  # of an enrichment failure was a line in the log.
  #
  # One surface with two tabs rather than two dashboard cards. It is one job done by
  # one person, and both counts belong in front of them at once; the tabs are plain
  # links so each list keeps its own paging with no JS.
  #
  # Reachable by :admin and the devolved-admin tier (User#admin_delegate?), like
  # re-parent and the tombstone registry: working this list is custodial repository
  # care, which is exactly what that tier is for. It is read-only — every action it
  # leads to (finish the deposit, replace the file) is gated on its own surface.
  class DepositTriageController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    breadcrumb_for 'Deposits needing attention', :admin_deposit_triage_path

    # Borrow CatalogController's Solr config so DepositTriageSearchBuilder behaves
    # like the catalog's (same pattern as TombstonesController and ReparentController).
    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    TABS = {
      'unconfirmed' => 'Waiting on a depositor',
      'incomplete'  => 'Missing something'
    }.freeze

    def index
      @state = TABS.key?(params[:state]) ? params[:state] : 'unconfirmed'
      @response = StuckDeposits.call(scope: self, state: @state.to_sym, page: params[:page])
      # Both tabs carry a count, so the inactive one says whether it is worth
      # opening. The active tab's comes from the response already in hand.
      @counts = TABS.keys.index_with { |state| state == @state ? @response.total : count_for(state) }
      # One batch so audit_event_actor resolves names from cache per row rather
      # than making a directory request each time (see AuditEventsHelper).
      NuidResolver.names_for(@response.documents.pluck('depositor_ssi'))
    end

    private

      def count_for(state)
        StuckDeposits.call(scope: self, state: state.to_sym, page: 1).total
      end
  end
end
