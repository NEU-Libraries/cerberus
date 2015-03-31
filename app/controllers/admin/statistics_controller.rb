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
    @core_file_count = get_count_for_core_files
    @user_count = User.find(:all).length

    @content_type_counts = sort_content_type_counts
  end

  private

    def verify_admin
      redirect_to root_path unless current_user.admin?
    end

    def get_count_for_public_files
      model_type = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:CoreFile"
      return ActiveFedora::SolrService.count("has_model_ssim:\"#{model_type}\" AND read_access_group_ssim:(public)")
    end

    def get_count_for_private_files
      model_type = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:CoreFile"
      return ActiveFedora::SolrService.count("has_model_ssim:\"#{model_type}\" AND -read_access_group_ssim:(public)")
      return query_result.length
    end

    def get_count_for_core_files
      model_type = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:CoreFile"
      return ActiveFedora::SolrService.count("has_model_ssim:\"#{model_type}\"")
      return query_result.length
    end

    def get_count_for_model_type(model_string)
      model_type = ActiveFedora::SolrService.escape_uri_for_query "#{model_string}"
      # ignoring smart collections, so they don't inflate collection count
      return ActiveFedora::SolrService.count("has_model_ssim:\"#{model_type}\"  -smart_collection_type_tesim:[* TO *]")
    end

    def get_count_for_content_obj(model_string)
      # only finding canonical objects to avoid derivatives
      return ActiveFedora::SolrService.count("canonical_class_tesim:\"#{model_string}\"")
    end

    def sort_content_type_counts
      h = Hash.new()
      h["Audio Files"] = get_count_for_content_obj("AudioFile")
      h["Image Files"] = get_count_for_content_obj("ImageMasterFile")
      h["Excel Files"] = get_count_for_content_obj("MsexcelFile")
      h["Powerpoint Files"] = get_count_for_content_obj("MspowerpointFile")
      h["Word Files"] = get_count_for_content_obj("MswordFile")
      h["PDF Files"] = get_count_for_content_obj("PdfFile")
      h["Text Files"] = get_count_for_content_obj("TextFile")
      h["Video Files"] = get_count_for_content_obj("VideoFile")
      h["Zip Files"] = get_count_for_content_obj("ZipFile")

      h.sort_by { |type, value| value }.reverse!
    end

end
