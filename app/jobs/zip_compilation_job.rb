class ZipCompilationJob
  include Hydra::PermissionsQuery
  include Rails.application.routes.url_helpers
  include MimeHelper

  attr_accessor :title, :comp_pid, :entry_ids, :nuid, :large

  def queue_name
    :zip_compilation
  end

  def initialize(user, compilation, large = false)
    if !user.nil?
      self.nuid = user.nuid
    else
      self.nuid = nil
    end
    self.title = compilation.title
    self.comp_pid = compilation.pid
    self.entry_ids = compilation.entry_ids
    self.large = large
  end

  def run
    begin
      if !nuid.nil?
        user = User.find_by_nuid(nuid)
      else
        user = nil
      end
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
      dir = tempdir.join(self.comp_pid.gsub(":", "_"))

      # Removes any stale zip files that might still be sitting around.
      if File.directory? dir
        # Only remove the directory if it's older than an hour
        if ((Time.now.utc - DateTime.parse(File.stat(dir).mtime.to_s)) / 1.hour) > 1
          FileUtils.rm_rf dir
        else
          return
        end
      end

      FileUtils.mkdir_p dir

      temp_zipfile_name = dir.to_s + "/temp.zip"
      temp_txt = "#{self.comp_pid.gsub(":", "_")}.txt"

      # Kludge to avoid putting all zip items into memory
      Zip::File.open(temp_zipfile_name, Zip::File::CREATE) do |zipfile|
        zipfile.get_output_stream(temp_txt) { |f| f.puts "" }
      end

      self.entry_ids.each do |id|

        obj = ActiveFedora::SolrService.query("id:\"#{id}\"")
        doc = SolrDocument.new(obj.first)
        if doc.klass == "CoreFile"
          zip_core_file(doc, user, temp_zipfile_name)
        elsif doc.klass == 'Collection'
          zip_collection(doc, user, temp_zipfile_name)
        end
      end

      # Remove temp txt file
      Zip::File.open(temp_zipfile_name) do |zipfile|
        zipfile.remove(temp_txt)
      end

      if self.large
        time = Time.now.to_i
        large_path = "#{Rails.application.config.tmp_path}/large/#{sess_id}"
        full_large_path = "#{large_path}/#{time}.zip"

        FileUtils.mkdir_p large_path
        FileUtils.mv(temp_zipfile_name, full_large_path)

        # Email user their download link
        LargeDownloadMailer.download_alert(time, self.nuid, self.sess_id).deliver!
      else
        # Rename temp path to full path so download can pick it up
        FileUtils.mv(temp_zipfile_name, safe_zipfile_name)
      end

      return safe_zipfile_name
    rescue Exception => exception
      if !self.nuid.blank?
        name = User.find_by_nuid(self.nuid).name
      else
        name = "Not Logged In"
      end
      ExceptionNotifier.notify_exception(exception, :backtrace => "#{$@}", :data => {:user => "#{name}"})
    end
  end

  private

    # Generates a temporary directory name devoid of spaces and colons
    def safe_zipfile_name
      safe_title = self.title.gsub(/\s+/, "")
      safe_title = safe_title.gsub(":", "_")
      return "#{Rails.application.config.tmp_path}/#{self.comp_pid.gsub(":", "_")}/#{safe_title}.zip"
    end

    def zip_core_file(doc, user, temp_zipfile_name)
      begin
        id = doc.pid
        if CoreFile.exists?(id)
          cf = CoreFile.find(id)
          if !(cf.under_embargo?(user)) && !cf.tombstoned?
            content = cf.canonical_object
            if !user.nil? ? user.can?(:read, content) : content.public?
              if content.content.content && content.class != ImageThumbnailFile
                download_label = I18n.t("drs.display_labels.#{content.klass}.download")
                Zip::File.open(temp_zipfile_name) do |zipfile|
                  zipfile.add("#{self.title}/neu_#{id.split(":").last}-#{download_label}.#{extract_extension(content.properties.mime_type.first, File.extname(content.original_filename || "").delete!("."))}", content.fedora_file_path)
                end
              end
            end
          end
        end
      rescue Exception => error
        # Any number of things could be wrong with the core file - malformed due to error
        # or migration failure. Emails aren't currently working out of jobs. A TODO for later
      end
    end

    def zip_collection(doc, user, temp_zipfile_name)
      id = doc.pid
      if Collection.exists?(id)
        col = Collection.find(id)
        if !col.tombstoned?
          descendents = doc.all_descendent_files
          descendents.each do |c|
            zip_core_file(c, user, temp_zipfile_name)
          end
        end
      end
    end

end
