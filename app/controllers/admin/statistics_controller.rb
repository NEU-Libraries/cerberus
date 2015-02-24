class Admin::StatisticsController < ApplicationController

  before_filter :authenticate_user!
  before_filter :verify_admin

  def index
    @page_title = "Stats Home"
    @community_count = get_count_for_model_type("info:fedora/afmodel:Community")
    @collection_count = get_count_for_model_type("info:fedora/afmodel:Collection")
    @core_file_count = get_count_for_model_type("info:fedora/afmodel:CoreFile")
  end

  private

    def verify_admin
      redirect_to root_path unless current_user.admin?
    end

    def get_count_for_model_type(model_string)
      model_type = ActiveFedora::SolrService.escape_uri_for_query "#{model_string}"
      # ignoreing smart collections, so they don't inflate collection count
      query_result = ActiveFedora::SolrService.query("has_model_ssim:\"#{model_type}\"  -smart_collection_type_tesim:[* TO *]")
      return query_result.length
    end

end
