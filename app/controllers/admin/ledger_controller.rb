# frozen_string_literal: true

module Admin
  # The ledger — one surface holding the two things staff read together.
  #
  # **Requests** is a shared queue: what depositors have asked for, who picked
  # it up, and what is still outstanding. It replaces a group-addressed inbox
  # message, which could never show that, because a message is dismissed per
  # person.
  #
  # **Activity** is the write-once record of what the repository did — loads,
  # cascades, reindexes, showcase promotions — and the daily digest that sums a
  # day up. Nothing here is worked. Librarians read it, and act elsewhere; the
  # showcase list in particular is read after the fact, to catch a work promoted
  # onto a showcase it does not belong on, or filed under the wrong genre.
  #
  # Two tabs rather than two cards: it is one sitting by one person, and the
  # tabs are plain links so each list keeps its own paging with no JS. Reachable
  # by :admin and the devolved-admin tier, like deposit triage — reading a queue
  # is custodial repository care, which is what that tier is for.
  class LedgerController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    breadcrumb_for 'Requests & activity', :admin_ledger_path

    TABS = {
      'requests' => 'Requests',
      'activity' => 'Activity'
    }.freeze

    PER_PAGE = 50

    def index
      @tab = TABS.key?(params[:tab]) ? params[:tab] : 'requests'
      @open_count = StaffRequest.unresolved.count
      @tab == 'requests' ? load_requests : load_activity
    end

    private

      def load_requests
        @status = params[:status].presence || 'open'
        @requests = StaffRequest.with_status(@status).oldest_first.page(params[:page]).per(PER_PAGE)
        prime_names(@requests.flat_map { |r| [r.requester_nuid, r.claimed_by_nuid, r.resolved_by_nuid] })
      end

      def load_activity
        @kind = params[:kind].presence
        @notices = AdminNotice.of_kind(@kind).newest_first.page(params[:page]).per(PER_PAGE)
        prime_names(@notices.map(&:actor_nuid))
      end

      # One directory round-trip for the whole page. audit_event_actor resolves
      # per row off Rails.cache, so priming here is the difference between one
      # batch and a request per distinct NUID.
      def prime_names(nuids)
        NuidResolver.names_for(nuids.compact.uniq)
      end
  end
end
