# frozen_string_literal: true

module Admin
  # Requests and activity, two tabs over one AdminNotice table. See
  # docs/admin.md. Reachable by :admin and by the devolved-admin tier, like
  # deposit triage.
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

    # A digest sums a whole day, so it gets a page to itself.
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

      def ordered(scope)
        @tab == 'digests' ? scope.by_day : scope.newest_first
      end
  end
end
