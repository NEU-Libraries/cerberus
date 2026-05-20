# frozen_string_literal: true

module Authorizable
  extend ActiveSupport::Concern

  included do
    rescue_from CanCan::AccessDenied do
      render template: 'errors/forbidden', status: :forbidden
    end
  end

  private

    def render_gone(record)
      render template: 'errors/gone', status: :gone, locals: { record: record }
    end

    def authorize_show!
      @permissions = AtlasRb::Resource.permissions(params[:id])
      authorize! :read, solr_doc_from_permissions(@permissions)
    end

    def authorize_edit!
      @permissions = AtlasRb::Resource.permissions(params[:id])
      authorize! :edit, solr_doc_from_permissions(@permissions)
    end

    def authorize_tombstone!
      @permissions = AtlasRb::Resource.permissions(params[:id])
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
        'depositor_ssi'           => permissions.try(:depositor)
      )
    end
end
