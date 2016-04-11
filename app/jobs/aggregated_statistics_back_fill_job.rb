class AggregatedStatisticsBackFillJob
  def queue_name
    :aggregated_statistics
  end

  attr_accessor :date

  def initialize(date)
    self.date = date #start this job with the last friday prior to the friday that you are going to start the scheduled job with. ie if you are starting the scheduled job to run for Fri, 15 Apr 2016 23:59:59 -0400 then initiliaze this job with Fri, 08 Apr 2016 23:59:59 -0400
  end

  def run
    require 'fileutils'

    job_id = "#{Time.now.to_i}-aggregated-statistics-backfill"
    FileUtils.mkdir_p "#{Rails.root}/log/#{job_id}"

    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/aggregated-statistics-job-failed-pids.log")

    progress_logger = Logger.new("#{Rails.root}/log/#{job_id}/aggregated-statistics-job.log")
    progress_logger.info "#{Time.now} - Processing #{Impression.count(:ip_address, :distinct => true)} impressions."

    #queue off back fill from given date until the beginning of time
    if (date > (DateTime.now.-2.years))
      AggregatedStatisticsJob.new(date).run #run the week being kicked off
      AggregatedStatisticsBackFillJob.new(date.-1.week).run #run this job again for the week before
    else
      #we don't have stats this old, lets stop the process
    end


  end

end
