class LargeDownloadMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def download_alert(time, nuid, session_id)
    user = !nuid.blank? ? User.find_by_nuid(nuid) : nil
    @name = user.pretty_name || "No name set.  Uh oh!"
    @nuid = nuid || "No nuid set.  Uh oh!"
    @time = time || "No time set. Uh oh!"
    @file_url = large_download_url(session_id: session_id, time: time)  || "No url set.  Uh oh!"
    mail(to: user.email,
         subject: "[DRS] Large download link",
         content_type: "text/html")
  end
end
