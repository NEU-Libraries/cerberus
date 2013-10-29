class CartDownloadJob 

  attr_accessor :sess_id, :pids, :nuid, :user, :path

  def initialize(sess_id, pids, nuid) 
    self.sess_id = sess_id
    self.pids = pids 
    self.nuid = nuid
  end

  def queue_name 
    :cart_download
  end

  # The directory used to write the zipfile is cleared by the download action
  # in the shopping_cart controller, which is also the only place where the job is 
  # currently executed from.  
  def run
    self.user = User.find_by_email(nuid)
    self.path = "#{Rails.root}/tmp/carts/#{sess_id}"

    FileUtils.mkdir_p path
    full_path = "#{path}/cart.zip"

    Zip::Archive.open(full_path, Zip::CREATE) do |io| 
      pids.each do |pid| 
        item = ActiveFedora::Base.find(pid, cast: true)

        if user.can? :read, item 
          io.add_buffer("downloads/#{item.content.label}", item.content.content) 
        end
      end
    end
  end
end