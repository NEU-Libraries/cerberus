# frozen_string_literal: true

# Deep diff views reached from the Audit History tab's per-row "View" button —
# the v2 successor to DRS v1's per-object "Rights History" / "MODS History"
# pages. Read-only and admin-gated (same audience as the audit log itself, via
# `:read, :audit_event`).
#
# Type-agnostic: every data call hits Atlas's `/resources/:id/*` endpoints, so
# one controller serves Work / Collection / Community without branching.
#
#   #rights — paginated access-control ledger; each entry expands the audit
#             event's before/after ACL snapshot into a two-column diff.
class HistoriesController < ApplicationController
  before_action :authorize_history!

  PER_PAGE = 20

  def rights
    load_resource!
    events  = permission_events
    @events = Kaminari.paginate_array(events).page(page_for(events)).per(PER_PAGE)
  end

  private

    # Same gate as the History tab. Non-admins fail here and land on the shared
    # 403 page (Authorizable's rescue_from CanCan::AccessDenied).
    def authorize_history!
      authorize! :read, :audit_event
    end

    # Resolve the resource for the page heading + a back-link to its audit log.
    # Doubles as id validation: an unknown id raises JSON::ParserError, which
    # Authorizable turns into a friendly 404.
    def load_resource!
      found           = AtlasRb::Resource.find(params[:id])
      @resource_klass = found.klass
      @resource_title = found.resource.title
    end

    def permission_events
      history = AtlasRb::Resource.history(params[:id], nuid: Current.nuid)
      Array(history['events']).select do |event|
        event['action'] == 'update' && event['change_type'] == 'permissions'
      end
    end

    # An explicit ?page wins; otherwise, when arriving via a "View" deep-link
    # (?at=<occurred_at>), land on whichever page holds that event so its
    # #anchor resolves. Defaults to the first page.
    def page_for(events)
      return params[:page] if params[:page].present? || params[:at].blank?

      index = events.index { |event| event['occurred_at'] == params[:at] }
      index ? (index / PER_PAGE) + 1 : 1
    end
end
