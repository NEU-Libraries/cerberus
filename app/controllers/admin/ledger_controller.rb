# frozen_string_literal: true

module Admin
  # The ledger — one surface holding the two things staff read together, and
  # one table behind both.
  #
  # **Requests** is what depositors have asked staff to do but cannot do
  # themselves. It replaces a group-addressed inbox message, which could never
  # show the queue at all, because a message is dismissed per person.
  #
  # **Activity** is what the repository did — loads, cascades, reindexes,
  # showcase promotions — and the daily digest that sums a day up. The showcase
  # rows in particular are read after the fact, to catch a work promoted onto a
  # showcase it does not belong on, or filed under the wrong genre.
  #
  # Neither list is worked here. Staff read, act on the object's own surface,
  # and coordinate off-site, so the tabs are a filter on kind and nothing more.
  # Two tabs rather than two cards: it is one sitting by one person, and they
  # are plain links so each list keeps its own paging with no JS. Reachable by
  # :admin and the devolved-admin tier, like deposit triage.
  class LedgerController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    breadcrumb_for 'Requests & activity', :admin_ledger_path

    TABS = {
      'requests' => 'Requests',
      'activity' => 'Activity',
      'digests'  => 'Digests'
    }.freeze

    PER_PAGE = 50

    # A digest is a page-sized report of one whole day, so it gets a page.
    # Paging back through them reads the way the mailed summaries will arrive.
    DIGESTS_PER_PAGE = 1

    def index
      @tab = TABS.key?(params[:tab]) ? params[:tab] : 'requests'
      @kind = params[:kind].presence
      @on = requested_day
      @notices = ordered(filtered).page(params[:page]).per(per_page)
      # One directory round-trip for the whole page. audit_event_actor resolves
      # per row off Rails.cache, so priming here is the difference between one
      # batch and a request per distinct NUID.
      NuidResolver.names_for(@notices.map(&:actor_nuid).compact.uniq)
    end

    private

      # `?on=YYYY-MM-DD` narrows a tab to one day. It exists so a digest's
      # figures can link to what they counted: "1 made" on August 3rd means
      # the request made that day, not every request ever made.
      #
      # An unparseable date is ignored rather than raising — the value comes
      # from a query string, and a filtered page that quietly shows everything
      # beats an error page.
      def requested_day
        Date.iso8601(params[:on].to_s)
      rescue Date::Error
        nil
      end

      def filtered
        scope = scope_for(@tab).of_kind(@kind)
        @on ? scope.on_day(@on) : scope
      end

      def scope_for(tab)
        case tab
        when 'requests' then AdminNotice.requests
        when 'digests'  then AdminNotice.digests
        else                 AdminNotice.activity
        end
      end

      def per_page
        @tab == 'digests' ? DIGESTS_PER_PAGE : PER_PAGE
      end

      # A digest is about a day, so it sorts by that day. Everything else is an
      # event, which sorts by when it happened.
      def ordered(scope)
        @tab == 'digests' ? scope.by_day : scope.newest_first
      end
  end
end
