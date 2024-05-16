class IptcMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def iptc_alert
    @item_reports = Loaders::ItemReport.where('validity = TRUE AND modified = TRUE AND created_at > ?', DateTime.yesterday.end_of_day)

    if ["production", "secondary"].include? Rails.env
      mail(to: "Library-DRS-Metadata@northeastern.edu",
           subject: "[DRS] IPTC parse error(s) - #{pid}",
           content_type: "text/html")
    end
  end
end
