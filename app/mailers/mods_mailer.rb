class ModsMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def new_employee_alert(nuid, session_id)
    user = !nuid.blank? ? User.find_by_nuid(nuid) : nil
    @name = user.pretty_name || "No name set.  Uh oh!"
    @nuid = nuid || "No nuid set.  Uh oh!"
    @file_url = mods_download_path(session_id)  || "No url set.  Uh oh!"
    mail(to: user.email,
         subject: "[cerberus] MODS Export download link",
         content_type: "text/html")
  end
end
