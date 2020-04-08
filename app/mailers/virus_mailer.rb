class VirusMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def virus_alert(pid)
    @core_file = CoreFile.find(pid)

    if ["production", "secondary"].include? Rails.env
      mail(to: "Sarah <sj.sweeney@neu.edu>, dgcliff@northeastern.edu",
           subject: "[DRS] Virus Found - #{pid}",
           content_type: "text/html")
    end
  end
end
