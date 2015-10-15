class CartDownloadJob
  include MimeHelper

  attr_accessor :sess_id, :pids, :nuid, :user, :path, :ip_address

  def initialize(sess_id, pids, nuid, ip_addr)
    self.sess_id = sess_id
    self.pids = pids
    self.nuid = nuid
    self.ip_address = ip_addr
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
    full_path = "#{path}/drs_queue.zip"

    # Kludge to avoid putting all zip items into memory
    Zip::Archive.open(full_path, Zip::CREATE) do |io|
      io.add_buffer("_", "")
    end

    pids.each do |pid|
      if ActiveFedora::Base.exists?(pid)
        item = ActiveFedora::Base.find(pid, cast: true)
        download_label = I18n.t("drs.display_labels.#{item.klass}.download")
        if item.public? || user.can?(:read, item)
          Zip::Archive.open(full_path) do |io|
            io.add_buffer("downloads/neu_#{pid.split(":").last}-#{download_label}.#{extract_extension(item.properties.mime_type.first)}", item.content.content)
          end

          # Record the download
          opts = "pid = ? AND session_id = ? AND status = 'INCOMPLETE' AND action = 'download'"
          Impression.update_all("status = 'COMPLETE'", [opts, pid, sess_id])
        end
      end
    end

  end
end
