class AggregatedStatisticsDeleteJob
  def queue_name
    :aggregated_statistics_delete
  end

  attr_accessor :pid

  def initialize(pid)
    self.pid = pid
  end

  def run

    obj = ActiveFedora::Base.find(pid, cast: true)
    doc = SolrDocument.new obj.to_solr

    ancestors = doc.ancestors

    dates = AggregatedStatistic.where(pid: self.pid).map{ |x| x.processed_at }

    dates.each do |d|
      x = AggregatedStatistic.where(pid: self.pid, processed_at: d)

      ancestors.each do |pid|

        y = AggregatedStatistic.where(pid: pid, processed_at: d)

        y.views -= x.views
        y.downloads -= x.downloads
        y.streams -= x.streams
        y.loader_uploads -= x.loader_uploads
        y.user_uploads -= x.user_uploads
        y.form_edits -= x.form_edits
        y.xml_edits -= x.xml_edits
        y.size_increase -= x.size_increase
        y.spreadsheet_load_edits -= x.spreadsheet_load_edits
        y.xml_load_edits -= x.xml_load_edits

        y.save!

      end
    end

    # Clean up
    AggregatedStatistic.where(pid: self.pid).each do |as|
      as.destroy
    end

  end

end
