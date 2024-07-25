module Cerberus::ImpressionCount
  extend ActiveSupport::Concern

  included do

    def impression_views
      AggregatedStatistic.where(pid: self.pid).sum(:views)
    end

    def impression_downloads
      AggregatedStatistic.where(pid: self.pid).sum(:downloads)
    end

    def impression_streams
      AggregatedStatistic.where(pid: self.pid).sum(:streams)
    end
  end
end
