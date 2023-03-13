class CartDownloadJob
  include MimeHelper

  attr_accessor :sess_id, :pids, :nuid, :user, :path, :ip_address, :large

  def initialize(sess_id, pids, nuid, ip_addr, large = false)
    self.sess_id = sess_id
    self.pids = pids
    self.nuid = nuid
    self.ip_address = ip_addr
    self.large = large
  end

  def queue_name
    :cart_download
  end

  # The directory used to write the zipfile is cleared by the download action
  # in the shopping_cart controller, which is also the only place where the job is
  # currently executed from.
  def run
    self.user = !nuid.blank? ? User.find_by_nuid(nuid) : nil

    self.path = "#{Rails.application.config.tmp_path}/carts/#{sess_id}"

    FileUtils.mkdir_p path

    temp_path = "#{path}/in_progress.zip"
    full_path = "#{path}/drs_queue.zip"
    files_path = "#{path}/downloads"

    FileUtils.mkdir_p files_path

    pids.each do |pid|
      begin
        if ActiveFedora::Base.exists?(pid)
          item = ActiveFedora::Base.find(pid, cast: true)
          download_label = I18n.t("drs.display_labels.#{item.klass}.download")
          if item.public? || user.can?(:read, item)

            tmp_file_name = "neu_#{pid.split(":").last}-#{download_label}.#{extract_extension(item.properties.mime_type.first, File.extname(item.original_filename || "").delete!("."))}"
            relative_path = "./downloads/#{tmp_file_name}"
            `cd #{path} && ln -s #{item.fedora_file_path} #{relative_path}`
            `cd #{path} && zip -ur #{temp_path} #{relative_path}`
            File.unlink(files_path + "/" + tmp_file_name) # explicitly stating that we're removing a symlink to avoid confusion

            # Record the download
            opts = "pid = ? AND session_id = ? AND status = 'INCOMPLETE' AND action = 'download'"
            Impression.update_all("status = 'COMPLETE'", [opts, pid, sess_id])
          end
        end
      rescue Exception => error
        # Any number of things could be wrong with the core file - malformed due to error
        # or migration failure. Emails aren't currently working out of jobs. A TODO for later
      end
    end

    if File.exists?(temp_path) #if not, most likely deleted in tmp sweep, and this is a stale request anyway
      if self.large
        time = Time.now.to_i
        large_path = "#{Rails.application.config.tmp_path}/large/#{sess_id}"
        full_large_path = "#{large_path}/#{time}.zip"

        FileUtils.mkdir_p large_path
        FileUtils.mv(temp_path, full_large_path)

        # Email user their download link
        LargeDownloadMailer.download_alert(time, self.nuid, self.sess_id).deliver!
      else
        # Rename temp path to full path so download can pick it up
        FileUtils.mv(temp_path, full_path)
      end
    end
  end
end
