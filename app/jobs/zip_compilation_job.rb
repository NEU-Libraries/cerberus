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

    # Removes any stale zip files that might still be sitting around. 
    if File.directory?("#{Rails.root}/tmp/#{self.comp_pid}") 
      FileUtils.remove_dir ("#{Rails.root}/tmp/#{self.comp_pid}")
    end 

    FileUtils.mkdir_p ("#{Rails.root}/tmp/#{self.comp_pid}") 

    zipfile_name = safe_zipfile_name

    Zip::Archive.open(safe_zipfile_name, Zip::CREATE) do |io| 
      self.entry_ids.each do |id| 
        canon_object = NuCoreFile.find(id).canonical_object 

        if canon_object && !canon_object.content.content.nil?
          io.add_buffer("#{self.title}/#{canon_object.title}", canon_object.content.content)
        end
      end
    end
  end

  private 

    # Need to get FITS sorted out for this to work properly. 
    def assign_file_extension(entry) 
      return entry.title.first 
    end

    # Generates a temporary directory name devoid of spaces and colons 
    def safe_zipfile_name
      safe_title = self.title.gsub(/\s+/, "")
      timestamp = DateTime.now.strftime("%Y-%m-%d-%M-%s")

      return "#{Rails.root}/tmp/#{self.comp_pid}/#{safe_title}_archived_#{timestamp}.zip" 
    end
end
