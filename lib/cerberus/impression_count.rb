module Cerberus::ImpressionCount
  extend ActiveSupport::Concern

  included do
    # Return the number of unique* views this object has according to the
    # Impressions table.
    # * Unique as determined by viewing session_id
    def impression_views
      pids = []

      if !self.klass.blank? && (self.klass == "Community" || self.klass == "Collection" || self.klass == "Set")
        pids = self.all_descendent_files.map{|doc| doc.pid}
      else
        pids << self.pid
      end

      Impression.where("pid IN (?) AND action = ? AND public = ? AND status = 'COMPLETE'", pids, 'view', true).count
    end

    # Same as above, but with recorded download actions
    def impression_downloads
      pids = []

      if !self.klass.blank? && (self.klass == "Community" || self.klass == "Collection" || self.klass == "Set")
        pids = self.all_descendent_files.map{|doc| doc.pid}
      else
        pids << self.pid
      end

      Impression.where("pid = ? AND action = ? AND public = ? AND status = 'COMPLETE'", self.pid, 'download', true).count
    end

    # Same as above, but with recorded download actions
    def impression_streams
      pids = []

      if !self.klass.blank? && (self.klass == "Community" || self.klass == "Collection" || self.klass == "Set")
        pids = self.all_descendent_files.map{|doc| doc.pid}
      else
        pids << self.pid
      end

      Impression.where("pid = ? AND action = ? AND public = ? AND status = 'COMPLETE'", self.pid, 'stream', true).count
    end
  end
end
