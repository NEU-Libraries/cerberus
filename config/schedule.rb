# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

every 1.day, at: '1:30am'  do
  runner "MetadataMailer.daily_alert_email.deliver!"
  runner "MetadataMailer.daily_nonfeatured_alert_email.deliver!"
  runner "XmlMailer.daily_alert_email.deliver!"
  runner "IptcMailer.iptc_alert.deliver!"
  runner "ImpressionProcessingJob.new().run"
  runner "CacheWarmJob.new().run"
end

every :sunday, :at => '2:00am' do
  rake "-s sitemap:refresh"
end

every :sunday, :at => '4:00am' do
  runner "AggregatedStatisticsJob.new(nil).run"
end

# Learn more: http://github.com/javan/whenever
