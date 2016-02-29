module Cerberus::ImpressionCount
  extend ActiveSupport::Concern

  included do

    # Return the number of unique* views this object has according to the
    # Impressions table.
    # * Unique as determined by viewing session_id
    def impression_views
      Impression.where("pid IN (?) AND action = ? AND public = ? AND status = 'COMPLETE'", self.all_descendent_pids, 'view', true).count
    end

    # Same as above, but with recorded download actions
    def impression_downloads
      Impression.where("pid IN (?) AND action = ? AND public = ? AND status = 'COMPLETE'", self.all_descendent_content_object_pids, 'download', true).count
    end

    # Same as above, but with recorded download actions
    def impression_streams
      Impression.where("pid IN (?) AND action = ? AND public = ? AND status = 'COMPLETE'", self.all_descendent_content_object_pids, 'stream', true).count
    end
  end
end
