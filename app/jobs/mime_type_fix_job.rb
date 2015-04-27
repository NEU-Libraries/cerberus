class MimeTypeFixJob
  include ChecksumHelper
  include MimeHelper

  def queue_name
    :mime_type_fix
  end

  def run
    require 'fileutils'

    job_id = "#{Time.now.to_i}-mime_type_fix"
    FileUtils.mkdir_p "#{Rails.root}/log/#{job_id}"

    progress_logger = Logger.new("#{Rails.root}/log/#{job_id}/mime_type_fix-job.log")
    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/mime_type_fix-job-failed-pids.log")

    all_possible_models = [ "ImageSmallFile", "ImageMediumFile", "ImageLargeFile",
                            "ImageMasterFile", "ImageThumbnailFile", "MsexcelFile",
                            "MspowerpointFile", "MswordFile", "PdfFile", "TextFile",
                            "ZipFile", "AudioFile", "VideoFile" ]

    models_stringified = all_possible_models.inject { |base, str| base + " or #{str}" }
    models_query = RSolr.escape(models_stringified)

    query_string = "active_fedora_model_ssi:(#{models_stringified})"
    row_count = ActiveFedora::SolrService.count(query_string)
    query_result = ActiveFedora::SolrService.query(query_string, :fl => "id", :rows => row_count)

    progress_logger.info "#{Time.now} - Starting recharacterization for canonical objects."

    progress_logger.info "Processing #{query_result.length} content objects."

    query_result.each_with_index do |search_result, i|
      pid = query_result[i]["id"]
      begin
        # get fedora object for content file
        cf = ActiveFedora::Base.find(pid, cast:true)
        cf.properties.mime_type = extract_mime_type(cf.fedora_file_path)
        cf.properties.md5_checksum = new_checksum(cf.fedora_file_path)
        cf.save!
        progress_logger.info "#{Time.now} - Processed #{pid}"
      rescue Exception => error
        failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
        errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
        errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
        errors_for_pid.warn "#{Time.now} - #{$!}"
        errors_for_pid.warn "#{Time.now} - #{$@}"
      end
    end
    progress_logger.info "#{Time.now} - Done!"
  end
end
