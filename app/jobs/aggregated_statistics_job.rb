class AggregatedStatisticsJob
  def queue_name
    :aggregated_statistics
  end

  attr_accessor :communities, :collections, :files

  def run
    require 'fileutils'

    self.communities = Hash.new{|h, k| h[k] = Hash.new{ |h, k| h[k] = 0 }}
    self.collections = Hash.new{|h, k| h[k] = Hash.new{ |h, k| h[k] = 0 }}
    self.files = Hash.new{|h, k| h[k] = Hash.new{ |h, k| h[k] = 0 }}

    job_id = "#{Time.now.to_i}-aggregated-statistics"
    FileUtils.mkdir_p "#{Rails.root}/log/#{job_id}"

    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/aggregated-statistics-job-failed-pids.log")

    progress_logger = Logger.new("#{Rails.root}/log/#{job_id}/aggregated-statistics-job.log")
    progress_logger.info "#{Time.now} - Processing #{Impression.count(:ip_address, :distinct => true)} impressions."

    Impression.where("public = ? AND status = 'COMPLETE'", true).find_each do |imp|
      begin
        doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{imp.pid}\"").first
        if doc.klass == "CoreFile"

          # Stub out
          self.files["#{imp.pid}"]["view"]
          self.files["#{imp.pid}"]["download"]
          self.files["#{imp.pid}"]["stream"]

          self.files["#{imp.pid}"]["#{imp.action}"] += 1
          increase_parent_statistics(doc.parent, imp.action)
        else
          # Is a content object
          cf = doc.get_core_record

          # Stub out
          self.files["#{cf.pid}"]["view"]
          self.files["#{cf.pid}"]["download"]
          self.files["#{cf.pid}"]["stream"]

          self.files["#{cf.pid}"]["#{imp.action}"] += 1
          increase_parent_statistics(cf.parent, imp.action)
        end
      rescue Exception => error
        failed_pids_log.warn "#{Time.now} - Error processing PID: #{imp.pid}"
        errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{imp.pid}.log")
        errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
        errors_for_pid.warn "#{Time.now} - #{$!}"
        errors_for_pid.warn "#{Time.now} - #{$@}"
      end
    end

    column_names = ["type", "pid", "views", "downloads", "streams"]

    CSV.open("#{Rails.application.config.tmp_path}/aggregated_stats.csv", "ab") do |csv|
      csv << column_names

      self.communities.each do |key, hsh|
        csv << (["community", key].concat(hsh.values.to_a))
      end

      self.collections.each do |key, hsh|
        csv << (["collection", key].concat(hsh.values.to_a))
      end

      self.files.each do |key, hsh|
        csv << (["file", key].concat(hsh.values.to_a))
      end
    end

  end

  def increase_parent_statistics(pid, action)
    set = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first

    if set.klass == "Community"
      # Stub out
      self.communities["#{pid}"]["view"]
      self.communities["#{pid}"]["download"]
      self.communities["#{pid}"]["stream"]

      self.communities["#{pid}"]["#{action}"] += 1
    elsif set.klass == "Collection"
      # Stub out
      self.collections["#{pid}"]["view"]
      self.collections["#{pid}"]["download"]
      self.collections["#{pid}"]["stream"]

      self.collections["#{pid}"]["#{action}"] += 1
    end

    begin
      parent = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{set.parent}\"").first
      increase_parent_statistics(parent.pid, action)
    rescue
      #
    end
  end

end
