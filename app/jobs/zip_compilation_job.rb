class ZipCompilationJob
  include Hydra::PermissionsQuery
  include Rails.application.routes.url_helpers
  include MimeHelper

  attr_accessor :title, :comp_pid, :entry_ids, :nuid

  def queue_name
    :zip_compilation
  end

  def initialize(user, compilation)
    if !user.nil?
      self.nuid = user.nuid
    else
      self.nuid = nil
    end
    self.title = compilation.title
    self.comp_pid = compilation.pid
    self.entry_ids = compilation.entry_ids
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
        if ((Time.now.utc - DateTime.parse(File.stat(dir).mtime.to_s)) / 1.hour) < 1
          FileUtils.rm_rf dir
        else
          return
        end
      end

      FileUtils.mkdir_p dir

      temp_zipfile_name = dir.to_s + "/temp.zip"

      # Kludge to avoid putting all zip items into memory
      Zip::Archive.open(temp_zipfile_name, Zip::CREATE) do |io|
        io.add_buffer("#{self.comp_pid.gsub(":", "_")}.txt", "")
      end

      self.entry_ids.each do |id|

        if CoreFile.exists?(id)
          cf = CoreFile.find(id)
          if !(cf.under_embargo?(user))
            # cf.content_objects.each do |content|
            content = cf.canonical_object
            if !user.nil? ? user.can?(:read, content) : content.public?
              if content.content.content && content.class != ImageThumbnailFile
                download_label = I18n.t("drs.display_labels.#{content.klass}.download")
                Zip::Archive.open(temp_zipfile_name) do |io|
                  io.add_buffer("#{self.title}/neu_#{id.split(":").last}-#{download_label}.#{extract_extension(content.properties.mime_type.first)}", content.content.content)
                end
              end
            end
            # end
          end
        end
      end

      # Rename temp path to full path so download can pick it up
      FileUtils.mv(temp_zipfile_name, safe_zipfile_name)

      return safe_zipfile_name
    rescue Exception => exception
      if !self.nuid.blank?
        name = User.find_by_nuid(self.nuid).name
      else
        name = "Not Logged In"
      end
      ExceptionNotifier.notify_exception(exception, :env => request.env, :data => {:user => "#{name}"})
    end
  end

  private

    # Generates a temporary directory name devoid of spaces and colons
    def safe_zipfile_name
      safe_title = self.title.gsub(/\s+/, "")
      safe_title = safe_title.gsub(":", "_")
      return "#{Rails.application.config.tmp_path}/#{self.comp_pid.gsub(":", "_")}/#{safe_title}.zip"
    end
end
