class Admin::StatisticsController < ApplicationController
  helper_method :sort_column, :sort_direction
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

  def get_views
    @views = Impression.where('action = ?', 'view').order(sort_column + " " + sort_direction).paginate(:page => params[:page], :per_page => 10)
    render 'impressions', locals: {impressions: @views, type: "views" }
  end

  def get_downloads
    @downloads = Impression.where('action = ?', 'download').order(sort_column + " " + sort_direction).paginate(:page => params[:page], :per_page => 10)
    render 'impressions', locals: {impressions: @downloads, type: "downloads" }
  end

  def get_streams
    @streams = Impression.where('action = ?', 'stream').order(sort_column + " " + sort_direction).paginate(:page => params[:page], :per_page => 10)
    render 'impressions', locals: {impressions: @streams, type: "streams" }
  end

  def get_daily_report
    @page_title = "Daily Report"
    @cf_views = Impression.where('action = ? AND (created_at BETWEEN ? AND ?) AND status = ? AND public = ?', 'view', DateTime.yesterday.beginning_of_day, DateTime.yesterday.end_of_day, "COMPLETE", true).count
    @cf_downloads = Impression.where('action = ? AND (created_at BETWEEN ? AND ?) AND status = ? AND public = ?', 'download', DateTime.yesterday.beginning_of_day, DateTime.yesterday.end_of_day, "COMPLETE", true).count
    @cf_streams = Impression.where('action = ? AND (created_at BETWEEN ? AND ?) AND status = ? AND public = ?', 'stream', DateTime.yesterday.beginning_of_day, DateTime.yesterday.end_of_day, "COMPLETE", true).count
    @unique_users = Impression.where('(created_at BETWEEN ? AND ?) AND status = ? AND public = ?', DateTime.yesterday.beginning_of_day, DateTime.yesterday.end_of_day, "COMPLETE", true).uniq.pluck(:ip_address).count
    @new_users = User.where('created_at BETWEEN ? AND ?', DateTime.yesterday.beginning_of_day, DateTime.yesterday.end_of_day).count
    @loader_uploads = Loaders::ItemReport.where('validity = ? AND (created_at BETWEEN ? AND ?) AND change_type = ?', true, DateTime.yesterday.beginning_of_day, DateTime.yesterday.end_of_day, 'create').count
    @interface_uploads = UploadAlert.where('change_type = ? AND content_type != ? AND (created_at BETWEEN ? AND ?)', 'create', 'collection', DateTime.yesterday.beginning_of_day, DateTime.yesterday.end_of_day).count
    @uploads_count = @interface_uploads
    @interface_uploads = @interface_uploads - @loader_uploads
    @interface_upload_size = 0
    interface_upload_pids = UploadAlert.where('change_type = ? AND content_type != ? AND (created_at BETWEEN ? AND ?) AND (load_type != ? AND load_type != ?)', 'create', 'collection', DateTime.yesterday.beginning_of_day, DateTime.yesterday.end_of_day, "spreadsheet", "xml").pluck(:pid)
    interface_upload_pids.each do |pid|
      @interface_upload_size += get_core_file_size(pid)
    end
    @loader_upload_size = 0
    loader_upload_pids = Loaders::ItemReport.where('validity = ? AND (created_at BETWEEN ? AND ?) AND change_type = ?', true, DateTime.yesterday.beginning_of_day, DateTime.yesterday.end_of_day, 'create').pluck(:pid)
    loader_upload_pids.each do |pid|
      @loader_upload_size += get_core_file_size(pid)
    end
    @uploads_size = @interface_upload_size
    @interface_upload_size = @interface_upload_size - @loader_upload_size
    @edits = UploadAlert.where('change_type = ? AND content_type != ? AND (created_at BETWEEN ? AND ?)', 'update', 'collection', DateTime.yesterday.beginning_of_day, DateTime.yesterday.end_of_day).count
    @spreadsheet_edits = UploadAlert.where('change_type = ? AND content_type != ? AND (created_at BETWEEN ? AND ?) AND load_type = ?', 'update', 'collection', DateTime.yesterday.beginning_of_day, DateTime.yesterday.end_of_day, "spreadsheet").count
    @xml_loader_edits = UploadAlert.where('change_type = ? AND content_type != ? AND (created_at BETWEEN ? AND ?) AND load_type = ?', 'update', 'collection', DateTime.yesterday.beginning_of_day, DateTime.yesterday.end_of_day, "xml").count
    @loader_edits = @xml_loader_edits + @spreadsheet_edits
    @edit_tab_edits = @edits - @loader_edits
    @xml_edits = XmlAlert.where('created_at BETWEEN ? AND ?', DateTime.yesterday.beginning_of_day, DateTime.yesterday.end_of_day).count
    @cf_edits = @edits + @xml_edits
    render 'daily'
  end

  # def get_file_sizes
  #   render 'file_sizes', locals: {type: "file_sizes" }
  # end

  def export_file_sizes
    csv_string = CSV.generate do |csv|
      JSON.parse(FileSizeGraph.last.json_values).each do |hash|
        csv << hash.values
      end
    end
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

    def sort_column
      Impression.column_names.include?(params[:sort]) ? params[:sort] : "created_at"
    end

    def sort_direction
      %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
    end

    def get_core_file_size(pid)
      total = 0

      begin
        cf_doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first
        all_possible_models = [ "ImageSmallFile", "ImageMediumFile", "ImageLargeFile",
                                "ImageMasterFile", "ImageThumbnailFile", "MsexcelFile",
                                "MspowerpointFile", "MswordFile", "PdfFile", "TextFile",
                                "ZipFile", "AudioFile", "VideoFile", "PageFile", "VideoMasterFile", "AudioMasterFile" ]
        models_stringified = all_possible_models.inject { |base, str| base + " or #{str}" }
        models_query = ActiveFedora::SolrService.escape_uri_for_query models_stringified
        content_objects = solr_query_file_size("active_fedora_model_ssi:(#{models_stringified}) AND is_part_of_ssim:#{full_pid(pid)}")
        content_objects.map{|doc| total += doc.file_size.to_i}
      rescue Exception => error
        # File most likely deleted, or otherwise malformed
      end

      return total
    end

    def full_pid(pid)
      return ActiveFedora::SolrService.escape_uri_for_query "info:fedora/#{pid}"
    end

    def solr_query_file_size(query_string)
      row_count = ActiveFedora::SolrService.count(query_string)
      query_result = ActiveFedora::SolrService.query(query_string, :fl => "id file_size_tesim", :rows => row_count)
      return query_result.map { |x| SolrDocument.new(x) }
    end

end
