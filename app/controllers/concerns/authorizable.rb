# frozen_string_literal: true

module Authorizable
  extend ActiveSupport::Concern

  included do
    rescue_from CanCan::AccessDenied do |exception|
      # TODO: make this a proper view with template
      render plain: exception.message, status: :forbidden
    end
  end

  private

    def authorize_show!
      @permissions = AtlasRb::Resource.permissions(params[:id])
      authorize! :read, solr_doc_from_permissions(@permissions)
    end

    def authorize_edit!
      @permissions = AtlasRb::Resource.permissions(params[:id])
      authorize! :edit, solr_doc_from_permissions(@permissions)
    end

    def solr_doc_from_permissions(permissions)
      SolrDocument.new(
        'read_access_group_ssim' => permissions['read'],
        'edit_access_group_ssim' => permissions['edit']
      )
    end
end
