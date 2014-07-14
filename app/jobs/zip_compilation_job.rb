class ZipCompilationJob
  include Hydra::PermissionsQuery
  include Rails.application.routes.url_helpers

  attr_accessor :title, :comp_pid, :entry_ids, :nuid

  def queue_name
    :zip_compilation
  end

  def initialize(user, compilation)
    self.nuid = user.nuid
    self.title = compilation.title
    self.comp_pid = compilation.pid
    self.entry_ids = compilation.entry_ids
  end

  def run

    user = User.find_by_nuid(nuid)
    dir = Rails.root.join("tmp", self.comp_pid)

    # Removes any stale zip files that might still be sitting around.
    if File.directory? dir
      FileUtils.remove_dir dir
    end

    FileUtils.mkdir_p dir

    zipfile_name = safe_zipfile_name

    Zip::Archive.open(safe_zipfile_name, Zip::CREATE) do |io|
      self.entry_ids.each do |id|
        if NuCoreFile.exists?(id) && !NuCoreFile.find(id).under_embargo?(User.find_by_nuid(nuid))
          NuCoreFile.find(id).content_objects.each do |content|
            if user.can?(:read, content) && content.content.content && content.class != ImageThumbnailFile
              io.add_buffer("#{self.title}/#{id.split(":").last}-#{content.type_label}-#{content.title}#{File.extname(content.original_filename || "")}", content.content.content)
            end
          end
        end
      end
    end

    return zipfile_name
  end

  private

    # Generates a temporary directory name devoid of spaces and colons
    def safe_zipfile_name
      safe_title = self.title.gsub(/\s+/, "")
      timestamp = DateTime.now.strftime("%Y-%m-%d-%M-%s")

      return "#{Rails.root}/tmp/#{self.comp_pid}/#{safe_title}_archived_#{timestamp}.zip"
    end
end
