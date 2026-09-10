# frozen_string_literal: true

# Write gating for the standard resource controllers, and the translation of
# Atlas's refusals into friendly pages. See docs/authorization.md.
module Authorizable
  extend ActiveSupport::Concern

  # Raised by the `authorize_*!` helpers when AtlasRb hands back nothing for an
  # id. Neither nil-returning read raises by itself, so an unguarded unwrap
  # trips a NoMethodError on the nil downstream of the actual cause.
  # See docs/authorization.md.
  class ResourceNotFound < StandardError; end

  class_methods do
    # Deny-by-default write gating for works / collections / communities: the
    # :edit ability on the DESTINATION for new/create, on the resource for both
    # edit and update (never the form alone), and the tombstone gate on
    # tombstone. See docs/authorization.md.
    def authorize_resource_writes!(extra_edit: [])
      before_action :authenticate_user!,       only: %i[new create]
      before_action :authorize_destination!,   only: %i[new create]
      before_action :authorize_edit!,          only: %i[edit update] + Array(extra_edit)
      before_action :authorize_tombstone!,     only: %i[tombstone]
    end
  end

  included do
    rescue_from CanCan::AccessDenied do
      render template: 'errors/forbidden', status: :forbidden
    end

    # When Cerberus's gate says yes and Atlas's says no the write never
    # happened, so this is a plain 403, not a 500. Unhandled, the default Rails
    # exception trace leaks the params dump and file paths to the end user.
    rescue_from AtlasRb::ForbiddenError do
      render template: 'errors/forbidden', status: :forbidden
    end

    # A read Atlas refuses raises the bare ResourceError, which carries the
    # status; only a 403 is a refusal to render. A 401 or 422 here is our own
    # misconfiguration (a bad bearer token reads as "this resource does not
    # exist" on every page), so it keeps the loud default handler.
    #
    # MUST stay above the not-found handler. rescue_from matches the LAST
    # registered handler first, and AtlasRb::NotFoundError subclasses
    # ResourceError, so registering this below would swallow every write-side
    # 404 and make the not-found page unreachable.
    rescue_from AtlasRb::ResourceError do |e|
      raise e unless e.status == 403

      render template: 'errors/forbidden', status: :forbidden
    end

    # Reads and writes report a missing id differently, so two shapes land here:
    # a write raises NotFoundError, and a read returns nil for the caller to
    # turn into ResourceNotFound. A read no longer surfaces a missing id as a
    # parse error, so JSON::ParserError is deliberately absent — every atlas_rb
    # read consults the status before parsing, which means an unparseable body
    # is now our own bug rather than Atlas saying "no such thing", and it must
    # not be reported as a 404. See docs/authorization.md.
    rescue_from AtlasRb::NotFoundError, ResourceNotFound do
      render template: 'errors/not_found',
             status:   :not_found,
             locals:   { obj_type: controller_name.singularize }
    end
  end

  private

    def render_gone(record)
      render template: 'errors/gone', status: :gone, locals: { record: record }
    end

    # atlas_rb does NOT raise on the tombstone refusal — RaiseOnResourceError
    # passes the 422 (`code: "has_live_children"`) straight through as a raw
    # Faraday::Response. A caller that ignores it reports a false "deleted"
    # while the resource stays live. See docs/authorization.md.
    def perform_tombstone!(response, type:)
      if response.success?
        redirect_to root_path, notice: "#{type} deleted."
      elsif response.status == 422
        redirect_back_or_to(root_path, alert: "#{type} can't be deleted while it still contains live members. " \
                                              'Withdraw or move them first.')
      else
        redirect_back_or_to(root_path, alert: "#{type} could not be deleted.")
      end
    end

    def authorize_show!
      @permissions = AtlasRb::Resource.permissions(params[:id])
      raise ResourceNotFound if @permissions.nil?

      authorize! :read, solr_doc_from_permissions(@permissions)
    end

    def authorize_edit!
      authorize_edit_for!(params[:id])
    end

    # The create gate: :edit on the destination container. Leaves
    # @destination_id for the action. See docs/authorization.md.
    def authorize_destination!
      @destination_id = params[:collection_id].presence || params[:community_id].presence
      raise ResourceNotFound if @destination_id.blank?

      authorize_edit_for!(@destination_id)
    end

    def new_child_path(child)
      if params[:community_id].present?
        public_send(:"new_community_#{child}_path", params[:community_id])
      else
        public_send(:"new_collection_#{child}_path", params[:collection_id])
      end
    end

    def child_create_path(children)
      if params[:community_id].present?
        public_send(:"community_#{children}_path", params[:community_id])
      else
        public_send(:"collection_#{children}_path", params[:collection_id])
      end
    end

    def authorize_edit_for!(id)
      @permissions = AtlasRb::Resource.permissions(id)
      raise ResourceNotFound if @permissions.nil?

      authorize! :edit, solr_doc_from_permissions(@permissions)
    end

    def authorize_tombstone!
      @permissions = AtlasRb::Resource.permissions(params[:id])
      raise ResourceNotFound if @permissions.nil?

      authorize! :tombstone, solr_doc_from_permissions(@permissions, klass: tombstone_klass)
    end

    def tombstone_klass
      controller_name.classify
    end

    # Renders the Edit / Delete links iff the action behind them would be
    # authorized — never show a control the user can't use.
    def assign_show_abilities!(klass:)
      doc = solr_doc_from_permissions(@permissions, klass: klass)
      @can_edit = current_ability.can?(:edit, doc)
      @can_tombstone = current_ability.can?(:tombstone, doc)
    end

    def solr_doc_from_permissions(permissions, klass: nil)
      SolrDocument.new(
        'read_access_group_ssim'  => permissions.read,
        'edit_access_group_ssim'  => permissions.edit,
        'internal_resource_tesim' => klass.to_s,
        'depositor_ssi'           => permissions.try(:depositor),
        'proxy_uploader_ssi'      => permissions.try(:proxy_uploader)
      )
    end
end
