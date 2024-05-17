class IptcMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def iptc_alert
    @item_reports = Loaders::ItemReport.where('validity = TRUE AND modified = TRUE AND created_at > ?', DateTime.yesterday.end_of_day)

    count = 0

    if !@item_reports.nil?
      count += @item_reports.count
    end

    if ["production", "secondary"].include? Rails.env
      mail(to: "Library-DRS-Metadata@northeastern.edu",
           subject: "[DRS] IPTC parse - #{count} error(s)",
           content_type: "text/html")
    end
  end
end
