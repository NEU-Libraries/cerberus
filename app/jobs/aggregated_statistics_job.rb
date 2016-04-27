class AggregatedStatisticsJob
  require 'fileutils'

  def queue_name
    :aggregated_statistics
  end

  attr_accessor :date, :communities, :collections, :files

  def initialize(date)
    if date.nil?
      if AggregatedStatistic.count > 0
        self.date = AggregatedStatistic.last.processed_at.+1.week
      else
        self.date = DateTime.now.end_of_week.-2.days
      end
    else
      self.date = date.new_offset(0)
    end
  end

  def run
    self.communities = Hash.new{|h, k| h[k] = Hash.new{ |h, k| h[k] = 0 }}
    self.collections = Hash.new{|h, k| h[k] = Hash.new{ |h, k| h[k] = 0 }}
    self.files = Hash.new{|h, k| h[k] = Hash.new{ |h, k| h[k] = 0 }}

    job_id = "#{Time.now.to_i}-aggregated-statistics"
    FileUtils.mkdir_p "#{Rails.root}/log/#{job_id}"

    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/aggregated-statistics-job-failed-pids.log")

    progress_logger = Logger.new("#{Rails.root}/log/#{job_id}/aggregated-statistics-job.log")
    progress_logger.info "#{Time.now} - Processing #{Impression.count(:ip_address, :distinct => true)} impressions."

    # Get the complete, public impressions (views, downloads, streams) and aggregate up to parent collection(s) and community(ies)
    Impression.where("public = ? AND status = ? AND (created_at BETWEEN ? AND ?)", true, "COMPLETE", (date-6.days).beginning_of_day, date.end_of_day).find_each do |imp|
      begin
        doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{imp.pid}\"").first
        if doc.klass == "CoreFile"

          # Stub out
          stub_out_file_hash(imp.pid)

          self.files["#{imp.pid}"]["#{imp.action}"] += 1
          increase_parent_statistics(doc.parent, imp.action)
        else
          # Is a content object
          cf = doc.get_core_record

          # Stub out
          stub_out_file_hash(cf.pid)

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

    # User uploads and form edits for core_files and aggregate up to collection(s) and community(ies)
    UploadAlert.where('content_type != ? AND (created_at BETWEEN ? AND ?)', 'collection', (date-6.days).beginning_of_day, date.end_of_day).find_each do |upl|
      begin
        doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{upl.pid}\"").first
        if doc.klass == "CoreFile"
          # Stub out
          stub_out_file_hash(upl.pid)
          if upl.change_type == "create"
            self.files["#{upl.pid}"]["user_uploads"] += 1
            increase_parent_statistics(doc.parent, "user_uploads")
            size = get_core_file_size(doc.pid)
            self.files["#{upl.pid}"]["size_increase"] += size
            increase_parent_size(doc.parent, size)
          elsif upl.change_type == "update"
            self.files["#{upl.pid}"]["form_edits"] += 1
            increase_parent_statistics(doc.parent, "form_edits")
          end
        end
      rescue Exception => error
        failed_pids_log.warn "#{Time.now} - Error processing PID: #{upl.pid}"
        errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{upl.pid}.log")
        errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
        errors_for_pid.warn "#{Time.now} - #{$!}"
        errors_for_pid.warn "#{Time.now} - #{$@}"
      end
    end

    # Loader uploads and aggregate up
    Loaders::ImageReport.where('validity = ? AND (created_at BETWEEN ? AND ?)', true, (date-6.days).beginning_of_day, date.end_of_day).find_each do |upl|
      begin
        doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{upl.pid}\"").first
        if doc.klass == "CoreFile"
          # Stub out
          stub_out_file_hash(upl.pid)
          self.files["#{upl.pid}"]["loader_uploads"] += 1
          increase_parent_statistics(doc.parent, "loader_uploads")
          size = get_core_file_size(doc.pid)
          self.files["#{upl.pid}"]["size_increase"] += size
          increase_parent_size(doc.parent, size)
        end
      rescue Exception => error
        failed_pids_log.warn "#{Time.now} - Error processing PID: #{upl.pid}"
        errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{upl.pid}.log")
        errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
        errors_for_pid.warn "#{Time.now} - #{$!}"
        errors_for_pid.warn "#{Time.now} - #{$@}"
      end
    end


    # XML edits and aggregate up
    XmlAlert.where('created_at BETWEEN ? AND ?', (date-6.days).beginning_of_day, date.end_of_day).find_each do |e|
      begin
        doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{e.pid}\"").first
        if doc.klass == "CoreFile"
          # Stub out
          stub_out_file_hash(e.pid)
          self.files["#{e.pid}"]["xml_edits"] += 1
          increase_parent_statistics(doc.parent, "xml_edits")
        end
      rescue Exception => error
        failed_pids_log.warn "#{Time.now} - Error processing PID: #{e.pid}"
        errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{e.pid}.log")
        errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
        errors_for_pid.warn "#{Time.now} - #{$!}"
        errors_for_pid.warn "#{Time.now} - #{$@}"
      end
    end

    self.communities.each do |key, hsh|
      s = AggregatedStatistic.new(:pid=>key, :object_type=>"community", :views=>hsh["view"], :downloads=>hsh["download"], :streams=>hsh["stream"], :user_uploads=>hsh["user_uploads"], :loader_uploads=>hsh["loader_uploads"], :form_edits=>hsh["form_edits"], :xml_edits=>hsh["xml_edits"], :size_increase=>size_in_mb(hsh["size_increase"]), :processed_at=>date)
      s.save!
    end

    self.collections.each do |key, hsh|
      s = AggregatedStatistic.new(:pid=>key, :object_type=>"collection", :views=>hsh["view"], :downloads=>hsh["download"], :streams=>hsh["stream"], :user_uploads=>hsh["user_uploads"], :loader_uploads=>hsh["loader_uploads"], :form_edits=>hsh["form_edits"], :xml_edits=>hsh["xml_edits"], :size_increase=>size_in_mb(hsh["size_increase"]), :processed_at=>date)
      s.save!
    end

    self.files.each do |key, hsh|
      s = AggregatedStatistic.new(:pid=>key, :object_type=>"file", :views=>hsh["view"], :downloads=>hsh["download"], :streams=>hsh["stream"], :user_uploads=>hsh["user_uploads"], :loader_uploads=>hsh["loader_uploads"], :form_edits=>hsh["form_edits"], :xml_edits=>hsh["xml_edits"], :size_increase=>size_in_mb(hsh["size_increase"]), :processed_at=>date)
      s.save!
    end

    progress_logger.close()
    failed_pids_log.close()
  end

  def increase_parent_statistics(pid, action)
    set = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{pid}\"").first)
    if set.klass == "Community"
      # Stub out
      self.communities["#{pid}"]["view"]
      self.communities["#{pid}"]["download"]
      self.communities["#{pid}"]["stream"]
      self.communities["#{pid}"]["user_uploads"]
      self.communities["#{pid}"]["loader_uploads"]
      self.communities["#{pid}"]["form_edits"]
      self.communities["#{pid}"]["xml_edits"]

      self.communities["#{pid}"]["#{action}"] += 1
    elsif set.klass == "Collection"
      # Stub out
      self.collections["#{pid}"]["view"]
      self.collections["#{pid}"]["download"]
      self.collections["#{pid}"]["stream"]
      self.collections["#{pid}"]["user_uploads"]
      self.collections["#{pid}"]["loader_uploads"]
      self.collections["#{pid}"]["form_edits"]
      self.collections["#{pid}"]["xml_edits"]

      self.collections["#{pid}"]["#{action}"] += 1
    end

    begin
      if set.parent
        parent = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{set.parent}\"").first
        increase_parent_statistics(parent.pid, action)
      elsif set.smart_collection_type == "User Root" #this lets us go past a user root collection and into the commmunities they belong to
        emp = Employee.find("#{set.is_member_of.split("/").last}")
        emp.communities.each do |c|
          increase_parent_statistics(c.pid, action)
        end
      end
    rescue
      #
    end
  end

  def increase_parent_size(pid, size)
    set = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first

    if set.klass == "Community"
      # Stub out
      self.communities["#{pid}"]["size_increase"] #in MB
      self.communities["#{pid}"]["size_increase"] += size
    elsif set.klass == "Collection"
      # Stub out
      self.collections["#{pid}"]["size_increase"] #in MB
      self.collections["#{pid}"]["size_increase"] += size
    end

    begin
      if set.parent
        parent = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{set.parent}\"").first
        increase_parent_size(parent.pid, size)
      elsif set.smart_collection_type == "User Root" #this lets us go past a user root collection and into the commmunities they belong to
        emp = Employee.find("#{set.is_member_of.split("/").last}")
        emp.communities.each do |c|
          increase_parent_size(c.pid, size)
        end
      end
    rescue
      #
    end
  end

  def get_core_file_size(pid)
    total = 0
    cf_doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first
    all_possible_models = [ "ImageSmallFile", "ImageMediumFile", "ImageLargeFile",
                            "ImageMasterFile", "ImageThumbnailFile", "MsexcelFile",
                            "MspowerpointFile", "MswordFile", "PdfFile", "TextFile",
                            "ZipFile", "AudioFile", "VideoFile", "PageFile" ]
    models_stringified = all_possible_models.inject { |base, str| base + " or #{str}" }
    models_query = ActiveFedora::SolrService.escape_uri_for_query models_stringified
    content_objects = solr_query_file_size("active_fedora_model_ssi:(#{models_stringified}) AND is_part_of_ssim:#{full_pid(pid)}")
    content_objects.map{|doc| total += doc.file_size.to_i}
    return total
  end

  def full_pid(pid)
    return ActiveFedora::SolrService.escape_uri_for_query "info:fedora/#{pid}"
  end

  def solr_query_file_size(query_string)
    row_count = ActiveFedora::SolrService.count(query_string)
    query_result = ActiveFedora::SolrService.query(query_string, :fl => "id file_size_tesim", :rows => row_count)
    return query_result.map { |x| SolrDocument.new(x) }
  end

  def stub_out_file_hash(pid)
    self.files["#{pid}"]["view"]
    self.files["#{pid}"]["download"]
    self.files["#{pid}"]["stream"]
    self.files["#{pid}"]["user_uploads"]
    self.files["#{pid}"]["loader_uploads"]
    self.files["#{pid}"]["form_edits"]
    self.files["#{pid}"]["xml_edits"]
    self.files["#{pid}"]["size_increase"] #in MB
  end

  def size_in_mb(size)
    return (size/1024)/1024)
  end
end
