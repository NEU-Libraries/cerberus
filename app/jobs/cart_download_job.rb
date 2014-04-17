class CartDownloadJob

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
    self.user = User.find_by_nuid(nuid)
    self.path = "#{Rails.root}/tmp/carts/#{sess_id}"

    FileUtils.mkdir_p path
    full_path = "#{path}/drs_queue.zip"

    Zip::Archive.open(full_path, Zip::CREATE) do |io|
      pids.each do |pid|
        if ActiveFedora::Base.exists?(pid)
          item = ActiveFedora::Base.find(pid, cast: true)

          if user.can? :read, item
            io.add_buffer("downloads/#{item.content.label}", item.content.content)

            # Record the download
            DrsImpression.create(pid: pid, session_id: sess_id, action: 'download',
                                  ip_address: ip_address)
          end
        end
      end
    end
  end
end
