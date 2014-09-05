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

        if CoreFile.exists?(id)
          cf = CoreFile.find(id)
          if !(cf.under_embargo?(User.find_by_nuid(nuid)))
            cf.content_objects.each do |content|
              if user.can?(:read, content) && content.content.content && content.class != ImageThumbnailFile
                download_label = I18n.t("drs.display_labels.#{content.klass}.download")
                io.add_buffer("#{self.title}/neu_#{id.split(":").last}-#{download_label}#{Rack::Mime::MIME_TYPES.invert[content.characterization.mime_type.first]}", content.content.content)
              end
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
      safe_title = safe_title.gsub(":", "_")
      return "#{Rails.root}/tmp/#{self.comp_pid}/#{safe_title}.zip"
    end
end
