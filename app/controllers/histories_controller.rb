# frozen_string_literal: true

# Deep diff pages reached from the Audit History tab's per-row "View" button:
# rights and MODS. Read-only and admin-gated via `:read, :audit_event`.
# Type-agnostic — one controller serves Work, Collection and Community.
# See docs/admin.md.
class HistoriesController < ApplicationController
  before_action :authorize_history!

  # One permission event per page: the Rights page is a per-row deep link.
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

    # Admin-only, the same gate as the Audit History tab. A refusal lands on
    # the shared 403 page via Authorizable's rescue_from CanCan::AccessDenied.
    def authorize_history!
      authorize! :read, :audit_event
    end

    # Also validates the id: an unknown one raises JSON::ParserError, which
    # Authorizable turns into a friendly 404.
    def load_resource!
      @resource_id    = params[:id]
      found           = AtlasRb::Resource.find(@resource_id)
      @resource_klass = found.klass
      @resource_title = found.resource.title
    end

    def permission_events
      history = AtlasRb::Resource.history(params[:id], nuid: Current.nuid)
      Array(history['events']).select do |event|
        event['change_type'] == 'permissions' &&
          AuditEventsHelper::PERMISSION_VIEW_ACTIONS.include?(event['action'])
      end
    end

    def page_for(events)
      return params[:page] if params[:page].present? || params[:at].blank?

      index = events.index { |event| event['occurred_at'] == params[:at] }
      index ? (index / PER_PAGE) + 1 : 1
    end

    # Newest-first, as Atlas returns them. resolve_from steps forward by one to
    # reach the *earlier* version, so that order is load-bearing.
    def version_ids
      @version_ids ||= @versions.pluck('version_id')
    end

    def resolve_to
      params[:to].presence || anchored_version_id || version_ids.first
    end

    def resolve_from(to)
      return params[:from].presence if params[:from].present?

      index = version_ids.index(to)
      index ? version_ids[index + 1] : nil
    end

    def anchored_version_id
      return if params[:at].blank?

      match = @versions.find { |version| version['created'] == params[:at] }
      match && match['version_id']
    end

    def mods_xml(version_id)
      AtlasRb::Resource.mods_version(params[:id], version_id, nuid: Current.nuid)
    end
end
