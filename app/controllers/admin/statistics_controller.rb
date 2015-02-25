class Admin::StatisticsController < ApplicationController

  before_filter :authenticate_user!
  before_filter :verify_admin

  def index
    @page_title = "Stats Home"
    @community_count = get_count_for_model_type("info:fedora/afmodel:Community")
    @collection_count = get_count_for_model_type("info:fedora/afmodel:Collection")
    @employee_file_count = get_count_for_model_type("info:fedora/afmodel:Employee")
    @public_core_file_count = get_count_for_public_files
    @private_core_file_count = get_count_for_private_files
    @user_count = User.find(:all).length

    @content_type_counts = sort_content_type_counts
  end

  private

    def verify_admin
      redirect_to root_path unless current_user.admin?
    end

    def get_count_for_public_files
      model_type = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:CoreFile"
      query_result = ActiveFedora::SolrService.query("has_model_ssim:\"#{model_type}\" AND read_access_group_ssim:(public)")
      return query_result.length
    end

    def get_count_for_private_files
      model_type = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:CoreFile"
      query_result = ActiveFedora::SolrService.query("has_model_ssim:\"#{model_type}\" AND -read_access_group_ssim:(public)")
      return query_result.length
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

    def sort_content_type_counts
      h = Hash.new()
      h["Audio Files"] = get_count_for_content_obj("info:fedora/afmodel:AudioFile")
      #not including derivatives
      h["Image Files"] = get_count_for_content_obj("info:fedora/afmodel:ImageMasterFile")
      h["Excel Files"] = get_count_for_content_obj("info:fedora/afmodel:MsexcelFile")
      h["Powerpoint Files"] = get_count_for_content_obj("info:fedora/afmodel:MspowerpointFile")
      h["Word Files"] = get_count_for_content_obj("info:fedora/afmodel:MswordFile")
      # This will include word derivatives...will look into a way to solve that...
      h["PDF Files"] = get_count_for_content_obj("info:fedora/afmodel:PdfFile")
      h["Text Files"] = get_count_for_content_obj("info:fedora/afmodel:TextFile")
      h["Video Files"] = get_count_for_content_obj("info:fedora/afmodel:VideoFile")
      h["Zip Files"] = get_count_for_content_obj("info:fedora/afmodel:ZipFile")

      h.sort_by { |type, value| value }.reverse!
    end

end
