module Cerberus::ImpressionCount
  extend ActiveSupport::Concern

  included do
    # Return the number of unique* views this object has according to the
    # Impressions table.
    # * Unique as determined by viewing session_id
    def impression_views
      Impression.where("pid = ? AND action = ? AND public = ? AND status = 'COMPLETE'", self.pid, 'view', true).count
    end

    # Same as above, but with recorded download actions
    def impression_downloads
      Impression.where("pid = ? AND action = ? AND public = ? AND status = 'COMPLETE'", self.pid, 'download', true).count
    end

    # Same as above, but with recorded download actions
    def impression_streams
      Impression.where("pid = ? AND action = ? AND public = ? AND status = 'COMPLETE'", self.pid, 'stream', true).count
    end
  end
end
