# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  include Authorizable
  include ImpersonationSession

  before_action do
    I18n.locale = :en
  end

  before_action :store_preferred_view
  before_action :set_current_nuid

  # Authorization is evaluated against the effective user, so a view-as
  # session renders the target's access decisions (acting-as leaves this as
  # the real admin — only writes are re-attributed). effective_user comes
  # from ImpersonationSession and is current_user when not impersonating.
  def current_ability
    @current_ability ||= Ability.new(effective_user)
  end

  # `match:` is forwarded to loaf so callers can opt into exact path matching.
  # The default (:inclusive) is loaf's own default, preserved for existing
  # callers. Cross-resource trails (e.g. a person under their community) pass
  # :exact so an ancestor whose path is a *prefix* of the current URL
  # (/communities/:id vs /communities/:id/people) stays a link instead of being
  # mis-marked as the current crumb.
  def breadcrumbs(id, editing: false, match: :inclusive)
    result = AtlasRb::Resource.find(id)
    item = result.resource
    # ancestor_chain carries each ancestor's title alongside its noid/klass, so
    # the whole trail is built from this single find — no per-ancestor round-trip.
    Array(item.ancestor_chain).each do |node|
      add_breadcrumb_for(node['noid'], node['klass'], node['title'], match: match)
    end

    if editing
      edit_breadcrumb_tail(item, result.klass)
    else
      add_breadcrumb_for(item.id, result.klass, item.title, match: match)
    end
  end

  # The tail of an edit-page trail: the resource itself becomes a link back to
  # its show page (`match: :exact` so loaf doesn't mark it current on the
  # `/edit` sub-path — inclusive matching otherwise treats `/works/:id/edit` as
  # "under" `/works/:id`), and a final non-link "Edit <Klass>" crumb is the
  # you-are-here. Lets an editor back out to the resource via the trail.
  def edit_breadcrumb_tail(item, klass)
    breadcrumb(item.title, public_send("#{klass.downcase}_path", item.id), match: :exact)
    breadcrumb("Edit #{klass}", public_send("edit_#{klass.downcase}_path", item.id))
  end

  def pretty_group(raw_group)
    Group.find_by(raw: raw_group)&.cosmetic || raw_group
  end

  def store_preferred_view
    session[:preferred_view] = params[:view] if params[:view]
  end

  private # ---------------------------------------------------------

    def set_current_nuid
      Current.nuid = current_user&.nuid || Rails.application.config.x.cerberus.guest_nuid
    end

    # The identity Cerberus-side writes are attributed to: the acting-as
    # target when an acting-as session is live, otherwise the authenticated
    # user. Matches the deposit convention — acting-as work belongs wholly
    # to the target, so their inbox (not the admin's) gets the follow-ups.
    def attributed_nuid
      Current.on_behalf_of.presence || Current.nuid
    end

    def add_breadcrumb_for(resource_id, klass, title, match: :inclusive)
      path = public_send("#{klass.downcase}_path", resource_id)
      breadcrumb(title, path, match: match)
    end
end
