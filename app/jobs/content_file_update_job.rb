class ContentFileUpdateJob
  def queue_name
    :content_file_update
  end

  # Cerberus::Application::Queue.push(MimeTypeFixJob.new(pid, job_id))

  def run
    require 'fileutils'
    job_id = "#{Time.now.to_i}-content_file_update"
    FileUtils.mkdir_p "#{Rails.root}/log/#{job_id}"

    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/content_file_update-job-failed-pids.log")

    all_possible_models = [ "ImageSmallFile", "ImageMediumFile", "ImageLargeFile",
                            "ImageMasterFile", "ImageThumbnailFile", "MsexcelFile",
                            "MspowerpointFile", "MswordFile", "PdfFile", "TextFile",
                            "ZipFile", "AudioFile", "VideoFile" ]

    models_stringified = all_possible_models.inject { |base, str| base + " or #{str}" }
    models_query = RSolr.escape(models_stringified)

    query_string = "active_fedora_model_ssi:(#{models_stringified})"
    row_count = ActiveFedora::SolrService.count(query_string)
    query_result = ActiveFedora::SolrService.query(query_string, :fl => "id", :rows => row_count)

    progress_logger = Logger.new("#{Rails.root}/log/#{job_id}/mime-type-fix-job.log")
    progress_logger.info "#{Time.now} - Moving mime type and checksum to properties for canonical objects."
    progress_logger.info "#{Time.now} - Processing #{query_result.length} content objects."

    query_result.each_with_index do |search_result, i|
      pid = query_result[i]["id"]
      begin
        doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first
        if doc.checksum.blank?
          Cerberus::Application::Queue.push(MimeTypeFixJob.new(pid, job_id))
        end
      rescue Exception => error
        failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
        errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
        errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
        errors_for_pid.warn "#{Time.now} - #{$!}"
        errors_for_pid.warn "#{Time.now} - #{$@}"
      end
    end
  end
end
