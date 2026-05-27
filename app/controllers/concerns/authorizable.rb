# frozen_string_literal: true

module Authorizable
  extend ActiveSupport::Concern

  # Raised by the `authorize_*!` helpers when AtlasRb returns a nil
  # permissions envelope — Atlas's `/resources/:id/permissions` returns
  # a 200 with no `"resource"` key for unknown IDs, so atlas_rb's
  # pass-through unwrapping yields nil rather than raising. Translating
  # that into an explicit sentinel here means the same rescue_from path
  # handles both the JSON::ParserError shape (from `Resource.find`'s
  # empty-body 404) and the nil-permissions shape (from the downloads /
  # before_action route).
  class ResourceNotFound < StandardError; end

  included do
    rescue_from CanCan::AccessDenied do
      render template: 'errors/forbidden', status: :forbidden
    end

    # Two flavours of "resource doesn't exist" land here:
    #
    #   1. `AtlasRb::Resource.find` (and its Work/Collection/Community
    #      siblings) call JSON.parse on Atlas's empty 404 body and the
    #      parser raises `unexpected end of input`.
    #   2. `AtlasRb::Resource.permissions` returns nil for unknown IDs;
    #      the `authorize_*!` helpers below raise `ResourceNotFound`
    #      in that case so we don't trip a `NoMethodError` on the nil.
    #
    # Both shapes render the same friendly 404 page rather than the
    # default Rails exception trace, with the singularized controller
    # name giving the template a sensible `obj_type` default
    # ("work" / "collection" / "community" / "download" / etc.).
    rescue_from JSON::ParserError, ResourceNotFound do
      render template: 'errors/not_found',
             status:   :not_found,
             locals:   { obj_type: controller_name.singularize }
    end
  end

  private

    def render_gone(record)
      render template: 'errors/gone', status: :gone, locals: { record: record }
    end

    def authorize_show!
      @permissions = AtlasRb::Resource.permissions(params[:id])
      raise ResourceNotFound if @permissions.nil?

      authorize! :read, solr_doc_from_permissions(@permissions)
    end

    def authorize_edit!
      @permissions = AtlasRb::Resource.permissions(params[:id])
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
