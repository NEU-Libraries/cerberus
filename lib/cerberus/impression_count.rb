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
      elsif !self.klass.blank? && self.klass == "Compilation"
        self.entries.each do |e|
          if e.klass == 'CoreFile'
            pids << e.pid
          else
            e.all_descendent_files.each do |f|
              pids << f.pid
            end
          end
        end
      else
        pids << self.pid
      end

      Impression.where("pid IN (?) AND action = ? AND public = ? AND status = 'COMPLETE'", pids, 'view', true).count
    end

    # Same as above, but with recorded download actions
    def impression_downloads
      pids = []

      if !self.klass.blank? && (self.klass == "Community" || self.klass == "Collection" || self.klass == "Set")
        #get content objects for descendent core files
        # pids = self.all_descendent_files.map{|doc| doc.pid}
        self.all_descendent_files.each do |doc|
          pids.concat doc.content_objects.map{|co| co.pid}
        end
      elsif !self.klass.blank? && self.klass == "CoreFile"
        # get content objects just for self
        pids = self.content_objects.map{|co| co.pid}
      elsif !self.klass.blank? && self.klass == "Compilation"
        self.entries.each do |e|
          if e.klass == 'CoreFile'
            pids.concat e.content_objects.map{|co| co.pid}
          else
            e.all_descendent_files.each do |f|
              pids.concat f.content_objects.map{|co| co.pid}
            end
          end
        end
      else
        # probably a content object itself
        pids << self.pid
      end

      Impression.where("pid IN (?) AND action = ? AND public = ? AND status = 'COMPLETE'", pids, 'download', true).count
    end

    # Same as above, but with recorded download actions
    def impression_streams
      pids = []

      if !self.klass.blank? && (self.klass == "Community" || self.klass == "Collection" || self.klass == "Set")
        #get content objects for descendent core files
        # pids = self.all_descendent_files.map{|doc| doc.pid}
        self.all_descendent_files.each do |doc|
          pids.concat doc.content_objects.map{|co| co.pid}
        end
      elsif !self.klass.blank? && self.klass == "CoreFile"
        # get content objects just for self
        pids = self.content_objects.map{|co| co.pid}
      elsif !self.klass.blank? && self.klass == "Compilation"
        self.entries.each do |e|
          if e.klass == 'CoreFile'
            pids.concat e.content_objects.map{|co| co.pid}
          else
            e.all_descendent_files.each do |f|
              pids.concat f.content_objects.map{|co| co.pid}
            end
          end
        end
      else
        # probably a content object itself
        pids << self.pid
      end

      Impression.where("pid IN (?) AND action = ? AND public = ? AND status = 'COMPLETE'", pids, 'stream', true).count
    end
  end
end
