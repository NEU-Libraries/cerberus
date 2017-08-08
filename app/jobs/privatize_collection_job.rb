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

    col_doc.public_descendents.each do |v|
      pid = v[0]
      doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first
      if !doc.blank? && doc.public?
        x = ActiveFedora::Base.find(doc.pid, cast: true)
        x.mass_permissions = "private"
        x.save!
      end
    end

    PrivatizeMailer.privatize_alert(self.pid, mailing_list).deliver!
  end
end
