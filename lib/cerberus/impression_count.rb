module Cerberus::ImpressionCount
  extend ActiveSupport::Concern

  included do

    # Return the number of unique* views this object has according to the
    # Impressions table.
    # * Unique as determined by viewing session_id
    def impression_views
      if self.klass != "Collection"
        Impression.where("pid IN (?) AND action = ? AND public = ? AND status = 'COMPLETE'", self.all_descendent_pids, 'view', true).count
      else
        AggregatedStatistic.where(pid: self.pid).sum(:views)
      end
    end

    # Same as above, but with recorded download actions
    def impression_downloads
      if self.klass != "Collection"
        Impression.where("pid IN (?) AND action = ? AND public = ? AND status = 'COMPLETE'", self.all_descendent_content_object_pids, 'download', true).count
      else
        AggregatedStatistic.where(pid: self.pid).sum(:downloads)
      end
    end

    # Same as above, but with recorded download actions
    def impression_streams
      if self.klass != "Collection"
        Impression.where("pid IN (?) AND action = ? AND public = ? AND status = 'COMPLETE'", self.all_descendent_content_object_pids, 'stream', true).count
      else
        AggregatedStatistic.where(pid: self.pid).sum(:streams)
      end
    end
  end
end
