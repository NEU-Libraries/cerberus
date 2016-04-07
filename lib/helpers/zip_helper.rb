module ZipHelper

  def safe_unzip(zip_file_path, output_dir)
    # For certain zip files, the gem we use struggles to open and extract their contents
    # It seems related to OSX's handling of large zip files, and their zip64 structure
    # Further reading can be had here - https://bitinn.net/10716/

    # As a result, in the event that the file doesn't open, or opens but only makes an empty
    # dir, we fall back and shell out to standard unzip at the linux level - this kludge seems
    # to be a reliable secondary step

    # Making a generalized helper method to re-use throughout the various places we handle
    # zips in the codebase

    # Make the output path if it doesn't already exist
    FileUtils.mkdir(output_dir) unless File.exists? output_dir

    # Attempts to extract all files with the gem, our ideal setup
    begin
      Zip::File.open(zip_file_path) do |zipfile|
        zipfile.each do |f|
          if !f.directory? && File.basename(f.name)[0] != "." # Don't extract directories or mac specific files
            fpath = File.join(dir_path, f.name)
            FileUtils.mkdir_p(File.dirname(fpath))
            zipfile.extract(f, fpath) unless File.exist?(fpath)
          end
        end
      end
    rescue Exception => error
      # we'll check for empty dir afterwards
    end

    # Empty dir?
    if Dir[output_dir].empty?
      # Standard gem zip extraction didn't work, let's shell out to unzip
      `unzip #{zip_file_path} -d #{output_dir}`
    end

    dir_list = Dir.glob("#{output_dir}/*")

    # Loop through and remove directories
    dir_list.delete_if do |item|
      File.directory?(item)
    end

    # returns file list with absolute paths
    return dir_list
  end

end
