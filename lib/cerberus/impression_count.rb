module Cerberus::ImpressionCount
  extend ActiveSupport::Concern

  included do

    # Return the number of unique* views this object has according to the
    # Impressions table.
    # * Unique as determined by viewing session_id
    def impression_views
      if self.klass != "Collection"
        # Switch to query per pid and combine values for better use of pid column index in sql
        total = 0
        self.all_descendent_pids.each do |pid|
          total += Impression.where("pid = ? AND action = ? AND public = ? AND status = 'COMPLETE'", pid, 'view', true).count
        end
        return total
      else
        AggregatedStatistic.where(pid: self.pid).sum(:views)
      end
    end

    # Same as above, but with recorded download actions
    def impression_downloads
      if self.klass != "Collection"
        # Switch to query per pid and combine values for better use of pid column index in sql
        total = 0
        self.all_descendent_content_object_pids.each do |pid|
          total += Impression.where("pid = ? AND action = ? AND public = ? AND status = 'COMPLETE'", pid, 'download', true).count
        end
        return total
      else
        AggregatedStatistic.where(pid: self.pid).sum(:downloads)
      end
    end

    # Same as above, but with recorded download actions
    def impression_streams
      if self.klass != "Collection"
        # Switch to query per pid and combine values for better use of pid column index in sql
        total = 0
        self.all_descendent_content_object_pids.each do |pid|
          total += Impression.where("pid = ? AND action = ? AND public = ? AND status = 'COMPLETE'", pid, 'stream', true).count
        end
        return total
      else
        AggregatedStatistic.where(pid: self.pid).sum(:streams)
      end
    end
  end
end
