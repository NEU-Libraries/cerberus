module Drs::ImpressionCount
  extend ActiveSupport::Concern

  included do
    # Return the number of unique* views this object has according to the
    # DrsImpressions table.
    # * Unique as determined by viewing session_id
    def impression_views
      DrsImpression.where("pid = ? AND action = ? AND status = 'COMPLETE'", self.pid, 'view').count
    end

    # Same as above, but with recorded download actions
    def impression_downloads
      DrsImpression.where("pid = ? AND action = ? AND status = 'COMPLETE'", self.pid, 'download').count
    end
  end
end
