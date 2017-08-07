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

    PrivatizeMailer.privatize_alert(self.pid, col_doc.public_descendents).deliver!

    desc_pids = col_doc.all_descendent_pids
    desc_pids.each do |p|
      doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{p}\"").first
      if !doc.blank? && doc.public?
        x = CoreFile.find(doc.pid)
        x.mass_permissions = "private"
        x.save!
      end
    end
  end
end
