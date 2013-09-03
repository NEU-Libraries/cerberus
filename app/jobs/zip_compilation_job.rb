require 'tmpdir' 

class ZipCompilationJob 

  def queue_name 
    :zip_compilation 
  end

  def initialize(compilation)
    @compilation = compilation 
  end

  def run 
    # Writes this compilations entry content to a temporary directory, returns the full path to said directory. 
    content_file_location = write_content_to_temp_dir(compilation)

    # Generate the zipfile path 
    zipfile_name = "#{Rails.root}/tmp/#{compilation.title}_zip_#{Time.now}" 

    # Zips all files at content_file_location 
    Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile| 
      Dir[File.join(content_file_location, "**", "**")].each do |file| 
        zipfile.add(file.sub(directory, ''), file) 
      end
    end

    return zipfile_name
  end

  private 

    # Creates a temporary directory and returns a string containing the path to it. 
    def write_content_to_temp_dir(compilation) 
      temporary_directory = FileUtils.mkdir_p("#{Rails.root}/tmp/#{compilation.title}_archive_#{Time.now}")

      compilation.entries.each do |entry| 
        create_content_file(entry) 
      end

      return temporary_directory.first 
    end

    # Create a file with this entry's content in the given temporary directory.  Tosses out blank files. 
    def create_content_file(entry, tempdir)
      if !entry.content.content.nil? 
        File.open("#{tempdir}/#{entry.title.first}", "w+") { |f| f.write(entry.content) }
      end 
    end
end
