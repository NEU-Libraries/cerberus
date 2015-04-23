class Loaders::ImageReport < FileReport
  attr_accessible :exception, :valid, :pid, :title, :collection, :iptc, :name, :email

  def self.create_success(core_file, user, iptc)
    x = ImageReport.new
    x.valid             = true
    x.pid               = core_file.pid
    x.collection        = core_file.parent
    x.name              = user.full_name
    x.email             = user.email
    x.title             = core_file.title
    x.iptc              = iptc
    x.save! ? x : false
  end

  def self.create_failure(user, exception, iptc)
    x = ImageReport.new
    x.valid             = false
    x.exception         = exception
    x.iptc              = iptc
    x.name              = user.full_name
    x.email             = user.email
    x.save! ? x : false
  end
end
