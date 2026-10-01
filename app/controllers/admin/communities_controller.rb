# frozen_string_literal: true

module Admin
  # Every community in one registry, as v1's /admin/communities was: find one by
  # title, then open its page, its Edit page or its People tab. The public
  # /communities index browses; this one is for managing.
  #
  # Admin and the devolved-admin tier. Reads are gated, so a delegate lists
  # only what they may discover; the People link is admin-only, as its tab is.
  class CommunitiesController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    breadcrumb_for 'Communities', :admin_communities_path

    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    PER_PAGE = 50

    # The People community is Atlas's home for personal roots, not a community
    # anyone manages here.
    FILTERS = ['internal_resource_tesim:Community', '-tombstoned_bsi:true', '-system_container_bsi:true'].freeze

    def index
      @q = params[:q].to_s.strip.presence
      builder = SearchBuilder.new(self).with(q: @q || '*:*', per_page: PER_PAGE, page: params[:page])
                             .with_filters(*FILTERS)
      builder = builder.merge(sort: 'title_ssi asc') if @q.nil?
      @response = Blacklight.default_index.search(params: builder)
      @parents = StructuralParents.call(documents: @response.documents)
    end
  end
end
