class AggregatedStatisticsBackFillJob
  def queue_name
    :aggregated_statistics_back_fill
  end

  attr_accessor :date

  def initialize(date)
    self.date = date #start this job with the last friday prior to the friday that you are going to start the scheduled job with. ie if you are starting the scheduled job to run for Fri, 15 Apr 2016 23:59:59 -0400 then initialize this job with Fri, 08 Apr 2016 23:59:59 -0400
  end

  def run
    require 'fileutils'

    #queue off back fill from given date until the beginning of time
    if (date > (Impression.order('created_at asc').limit(1).first.created_at))
      AggregatedStatisticsJob.new(date).run #run the week being kicked off
      prior_week = date.-1.week
      AggregatedStatisticsBackFillJob.new(prior_week).run #run this job again for the week before
    else
      #we don't have stats this old, lets stop the process
    end
  end

end
