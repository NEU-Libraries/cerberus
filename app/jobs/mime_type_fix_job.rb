class MimeTypeFixJob
  def queue_name
    :mime_type_fix
  end

  def run
    logger = Logger.new("#{Rails.root}/log/mime_type_fix.log")

    core_file_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:CoreFile"
    query_result = ActiveFedora::SolrService.query("has_model_ssim:\"#{core_file_model}\"", :fl => "id", :rows => 999999999)

    logger.info "#{Time.now} - Starting mime type audit."

    query_result.each_with_index do |search_result, i|
      pid = query_result[i]["id"]
      begin
        record = ActiveFedora::Base.find(pid, :cast=>true)
        canon = record.canonical_object

        # What does FITS think the canonical object's mime type should be?
        fits_mime = canon.mime_type
        # What is it set to in Fedora?
        fedora_mime = canon.content.mimeType

        if fits_mime != fedora_mime
          # Fix the mime type
          canon.content.mimeType = fits_mime
          canon.save!

          logger.warn "#{Time.now} - Mismatched mime type with PID: #{pid}"
          logger.warn "#{Time.now} - Reported FITS mime: #{fits_mime}"
          logger.warn "#{Time.now} - Reported fedora mime: #{fedora_mime}"
          logger.warn "#{Time.now} - Mime type reset to FITS"
        end
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
