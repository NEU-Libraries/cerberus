module ZipHelper

  def safe_unzip(zip_file_path, output_dir, squash = false)
    # For certain zip files, the gem we use struggles to open and extract their contents
    # It seems related to OSX's handling of large zip files, and their zip64 structure
    # Further reading can be had here - https://bitinn.net/10716/

    # As a result, in the event that the file doesn't open, or opens but only makes an empty
    # dir, we fall back and shell out to standard unzip at the linux level - this kludge seems
    # to be a reliable secondary step

    # Making a generalized helper method to re-use throughout the various places we handle
    # zips in the codebase

    # Need to accumulate original names to account for squashing
    original_names = []

    # Make the output path if it doesn't already exist
    FileUtils.mkdir(output_dir) unless File.exists? output_dir

    # Attempts to extract all files with the gem, our ideal setup
    begin
      Zip::File.open(zip_file_path) do |zipfile|
        zipfile.each do |f|
          if !f.directory? && File.basename(f.name)[0] != "." # Don't extract directories or mac specific files

            if squash
              # Legacy zip construction for certain loaders forces us to flatten internal
              # structure, so to do this we give each file a unique name to avoid collision
              original_names << f.name
              uniq_hsh = Digest::MD5.hexdigest("#{f.name}")[0,2]
              fpath = File.join(output_dir, "#{Time.now.to_f.to_s.gsub!('.','-')}-#{uniq_hsh}") # Names file time and hash string
            else
              fpath = File.join(output_dir, f.name)
            end

            FileUtils.mkdir_p(File.dirname(fpath))
            zipfile.extract(f, fpath) unless File.exist?(fpath)
          end
        end
      end
    rescue Exception => error
      # we'll check for empty dir afterwards
    end

    # Empty dir?
    if Dir[output_dir + "/*"].empty?
      # Standard gem zip extraction didn't work, let's shell out to unzip
      `unzip #{zip_file_path} -d #{output_dir}`
    end

    # Ensure all files have ok permissions
    FileUtils.chmod_R(0777, "#{output_dir}")

    dir_list = Dir.glob("#{output_dir}/*")

    # Loop through and remove directories
    dir_list.delete_if do |item|
      File.directory?(item)
    end

    if squash
      # returns file list with absolute paths and original names
      return [dir_list, original_names]
    else
      # returns file list with absolute paths
      return dir_list
    end
  end

end
