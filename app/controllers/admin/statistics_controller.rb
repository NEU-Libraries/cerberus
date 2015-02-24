class Admin::StatisticsController < ApplicationController

  before_filter :authenticate_user!
  before_filter :verify_admin

  def index
    @page_title = "Stats Home"
    @community_count = get_count_for_model_type("info:fedora/afmodel:Community")
    @collection_count = get_count_for_model_type("info:fedora/afmodel:Collection")
    @core_file_count = get_count_for_model_type("info:fedora/afmodel:CoreFile")

    # content type counts
    @audio_count = get_count_for_content_obj("info:fedora/afmodel:AudioFile")
    # Not including derivatives
    @image_count = get_count_for_content_obj("info:fedora/afmodel:ImageMasterFile")
    @excel_count = get_count_for_content_obj("info:fedora/afmodel:MsexcelFile")
    @ppt_count = get_count_for_content_obj("info:fedora/afmodel:MspowerpointFile")
    @word_count = get_count_for_content_obj("info:fedora/afmodel:MswordFile")
    # This will include word derivatives...will look into a way to solve that...
    @pdf_count = get_count_for_content_obj("info:fedora/afmodel:PdfFile")
    @text_count = get_count_for_content_obj("info:fedora/afmodel:TextFile")
    @video_count = get_count_for_content_obj("info:fedora/afmodel:VideoFile")
    @zip_count = get_count_for_content_obj("info:fedora/afmodel:ZipFile")
  end

  private

    def verify_admin
      redirect_to root_path unless current_user.admin?
    end

    def get_count_for_model_type(model_string)
      model_type = ActiveFedora::SolrService.escape_uri_for_query "#{model_string}"
      # ignoring smart collections, so they don't inflate collection count
      query_result = ActiveFedora::SolrService.query("has_model_ssim:\"#{model_type}\"  -smart_collection_type_tesim:[* TO *]")
      return query_result.length
    end

    def get_count_for_content_obj(model_string)
      model_type = ActiveFedora::SolrService.escape_uri_for_query "#{model_string}"
      # only finding canonical objects to avoid derivatives
      query_result = ActiveFedora::SolrService.query("has_model_ssim:\"#{model_type}\" AND canonical_tesim:[* TO *]")
      return query_result.length
    end

end
