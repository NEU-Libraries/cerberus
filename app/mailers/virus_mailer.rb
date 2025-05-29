class VirusMailer < ActionMailer::Base
  default from: "digitalrepositoryservice@northeastern.edu"

  def virus_alert(pid)
    @core_file = CoreFile.find(pid)

    if ["production", "secondary"].include? Rails.env
      mail(to: "Sarah <sj.sweeney@neu.edu>, d.cliff@northeastern.edu",
           subject: "[DRS] Virus Found - #{pid}",
           content_type: "text/html")
    end
  end
end
