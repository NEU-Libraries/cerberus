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

  # One permission event per page. The Rights page is reached via a per-row
  # "View" deep-link, so it shows that single event's before/after diff; the
  # prev/next walker steps to adjacent changes without stacking them.
  PER_PAGE = 1

  def rights
    load_resource!
    events  = permission_events
    @events = Kaminari.paginate_array(events).page(page_for(events)).per(PER_PAGE)
  end

  def mods
    load_resource!
    @versions = Array(AtlasRb::Resource.mods_versions(params[:id], nuid: Current.nuid)['versions'])
    return if @versions.empty?

    @to_id   = resolve_to
    @from_id = resolve_from(@to_id)
    return if @from_id.nil? # earliest version — nothing earlier to compare

    @diff = MODSDiff.call(from_xml: mods_xml(@from_id), to_xml: mods_xml(@to_id))
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
      @resource_id    = params[:id]
      found           = AtlasRb::Resource.find(@resource_id)
      @resource_klass = found.klass
      @resource_title = found.resource.title
    end

    # Permission events worth showing on the Rights page: the initial grant at
    # creation and every later ACL change (see
    # AuditEventsHelper::PERMISSION_VIEW_ACTIONS). Atlas suppresses no-op
    # permission writes, so each is a real before/after transition.
    def permission_events
      history = AtlasRb::Resource.history(params[:id], nuid: Current.nuid)
      Array(history['events']).select do |event|
        event['change_type'] == 'permissions' &&
          AuditEventsHelper::PERMISSION_VIEW_ACTIONS.include?(event['action'])
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

    # Version ids newest-first, as Atlas returns them.
    def version_ids
      @version_ids ||= @versions.pluck('version_id')
    end

    # The "after" side: explicit ?to, else the version a "View" deep-link
    # points at (the one whose `created` matches ?at), else the newest.
    def resolve_to
      params[:to].presence || anchored_version_id || version_ids.first
    end

    # The "before" side: explicit ?from, else the version immediately preceding
    # `to` (the next entry in the newest-first list). nil when `to` is the
    # earliest — there's nothing earlier to diff against.
    def resolve_from(to)
      return params[:from].presence if params[:from].present?

      index = version_ids.index(to)
      index ? version_ids[index + 1] : nil
    end

    # Best-effort: match a "View" deep-link's event timestamp (?at) to the
    # version created at that moment. Correlation is by timestamp, so a miss
    # just falls back to the newest version.
    def anchored_version_id
      return if params[:at].blank?

      match = @versions.find { |version| version['created'] == params[:at] }
      match && match['version_id']
    end

    def mods_xml(version_id)
      AtlasRb::Resource.mods_version(params[:id], version_id, nuid: Current.nuid)
    end
end
