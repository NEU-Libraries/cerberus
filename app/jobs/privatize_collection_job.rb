class PrivatizeCollectionJob
  attr_accessor :pid

  def initialize(pid)
    self.pid = pid
  end

  def queue_name
    :privatize_collection
  end

  def run
    col = Collection.find(self.pid)

    col_doc = SolrDocument.new col.to_solr

    mailing_list = col_doc.public_descendents

    # sentinel list
    content_list = [["Audio Master", "audio_master"],
                    ["Audio", "audio"],
                    ["Image Master", "image_master"],
                    ["Image Large", "image_large"],
                    ["Image Medium", "image_medium"],
                    ["Image Small", "image_small"],
                    ["Powerpoint", "mspowerpoint"],
                    ["Excel", "msexcel"],
                    ["Word ", "msword"],
                    ["Pdf", "pdf"],
                    ["Text", "text"],
                    ["Video Master", "video_master"],
                    ["Video", "video"],
                    ["Zip", "zip"]]

    sentinel = col.sentinel

    # privatize sentinel
    if !sentinel.blank?
      sentinel.core_file["mass_permissions"] = "private"
      # privatize core file and models
      content_list.each_with_index do |a, i|
        if !sentinel.send("#{a[1]}".to_sym).blank?
          sentinel.send("#{a[1]}".to_sym)["mass_permissions"] = "private"
        end
      end
    end

    col_doc.public_descendents.each do |v|
      pid = v[0]
      doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first
      if !doc.blank? && doc.public?
        x = ActiveFedora::Base.find(doc.pid, cast: true)
        x.mass_permissions = "private"
        x.save!
        x.propagate_metadata_changes!
      end
    end

    PrivatizeMailer.privatize_alert(self.pid, mailing_list).deliver!
  end
end
