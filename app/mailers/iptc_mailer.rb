class IptcMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def iptc_alert(pid)
    if ["production", "secondary"].include? Rails.env
      mail(to: "Library-DRS-Metadata@northeastern.edu",
           subject: "[DRS] IPTC Creator parse error - #{pid}",
           content_type: "text/html")
    end
  end
end
