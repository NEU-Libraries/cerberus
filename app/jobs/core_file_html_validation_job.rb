class CoreFileHtmlValidationJob
  def queue_name
    :core_file_html_validation
  end

  def run
    logger = Logger.new("#{Rails.root}/log/core_file_html_validation.log")

    core_file_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:CoreFile"
    query_result = ActiveFedora::SolrService.query("has_model_ssim:\"#{core_file_model}\"", :fl => "id", :rows => 999999999)

    logger.info "#{Time.now} - Starting core file audit."

    query_result.each_with_index do |search_result, i|
      pid = query_result[i]["id"]
      begin
        record = ActiveFedora::Base.find(pid, :cast=>true)
        CoreFilesController.new.render_mods_display(record).to_html
      rescue Exception => error
        logger.warn "#{Time.now} - Error processing PID: #{pid}"
        logger.warn "#{Time.now} - #{$!.inspect}"
        logger.warn "#{Time.now} - #{$!}"
        logger.warn "#{Time.now} - #{$@}"
      end
    end

    logger.info "#{Time.now} - Finished."

  end
end
