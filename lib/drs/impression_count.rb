module Drs::ImpressionCount 
  extend ActiveSupport::Concern

  included do 
    # Return the number of unique* views this object has according to the
    # DrsImpressions table. 
    # * Unique as determined by viewing session_id 
    def impression_count 
      DrsImpression.where("pid = ?", self.pid).count
    end
  end
end