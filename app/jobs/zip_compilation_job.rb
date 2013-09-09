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

  # def initialize(compilation_pid)
  #   self.compilation = Compilation.find(compilation_pid) 
  # end

  def run
    puts "Job executing take two"
    puts self.entry_ids

    # Removes any stale zip files that might still be sitting around. 
    if File.directory?("#{Rails.root}/tmp/#{self.comp_pid}") 
      FileUtils.remove_dir ("#{Rails.root}/tmp/#{self.comp_pid}")
    end 

    FileUtils.mkdir_p ("#{Rails.root}/tmp/#{self.comp_pid}") 

    zipfile_name = safe_zipfile_name

    puts "Zipfile name is #{zipfile_name}"

    Zip::ZipOutputStream::open(safe_zipfile_name) do |io| 
      self.entry_ids.each do |id|
        entry = GenericFile.find(id)

        io.put_next_entry("#{self.title}/#{assign_file_extension(entry)}") 
        io.write entry.content.content 
      end
    end 

    puts "Zipfile path is #{zipfile_name}"  
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
