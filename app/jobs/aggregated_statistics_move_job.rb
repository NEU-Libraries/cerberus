class AggregatedStatisticsMoveJob
  def queue_name
    :aggregated_statistics_move
  end

  attr_accessor :pid, :new_parent

  def initialize(pid, new_parent)
    self.pid = pid
    self.new_parent = new_parent
  end

  def run
    destination = ActiveFedora::Base.find(new_parent, cast: true)
    destination_doc = SolrDocument.new destination.to_solr

    new_ancestors = destination_doc.ancestors
    new_ancestors.unshift(new_parent)

    obj = ActiveFedora::Base.find(pid, cast: true)
    doc = SolrDocument.new obj.to_solr

    ancestors = doc.ancestors

    common_ancestor = doc.common_ancestor(new_parent)

    deduct_stop = ancestors.index(common_ancestor) - 1

    if deduct_stop >= 0
      deduct_stats_from = ancestors[0..deduct_stop]
    else
      deduct_stats_from = []
    end

    add_stop = new_ancestors.index(common_ancestor) - 1

    if add_stop >= 0
      add_stats_to = new_ancestors[0..add_stop]
    else
      add_stats_to = []
    end

    dates.each do |d|

      x = AggregatedStatistic.where(pid: self.pid, processed_at: d)

      deduct_stats_from.each do |y_pid|

        y = AggregatedStatistic.where(pid: y_pid, processed_at: d)

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

        add_stats_to.each do |z_pid|

          z = AggregatedStatistic.where(pid: z_pid, processed_at: d) #if none, make one TODO

          if z.blank?
            z = AggregatedStatistic.new(:pid=>z_pid, :object_type=>"collection")
          end

          z.views += x.views
          z.downloads += x.downloads
          z.streams += x.streams
          z.loader_uploads += x.loader_uploads
          z.user_uploads += x.user_uploads
          z.form_edits += x.form_edits
          z.xml_edits += x.xml_edits
          z.size_increase += x.size_increase
          z.spreadsheet_load_edits += x.spreadsheet_load_edits
          z.xml_load_edits += x.xml_load_edits

          z.save!

        end
      end
    end

  end

end
