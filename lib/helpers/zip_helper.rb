module ZipHelper

  def safe_unzip(zip_file_path, output_dir, squash = false)
    # For certain zip files, the gem we use struggles to open and extract their contents
    # It seems related to OSX's handling of large zip files, and their zip64 structure
    # Further reading can be had here - https://bitinn.net/10716/

    # Making a generalized helper method to re-use throughout the various places we handle
    # zips in the codebase

    # Need to accumulate original names to account for squashing
    original_names = []
    new_names = []
    result = []

    # Make the output path if it doesn't already exist
    FileUtils.mkdir(output_dir) unless File.exists? output_dir

    # Shell out to unzip
    `unzip #{zip_file_path} -d #{output_dir}`

    # Ensure all files have ok permissions
    FileUtils.chmod_R(0777, "#{output_dir}")

    dir_list = Dir.glob("#{output_dir}/*")

    Dir.glob("#{output_dir}/**/*").each do |path|
      if squash
        if !File.directory?(path) && File.basename(path)[0] != "."
          uniq_hsh = Digest::MD5.hexdigest("#{path}")[0,2]
          uniq_filename = "#{Time.now.to_f.to_s.gsub!('.','-')}-#{uniq_hsh}"
          new_path = File.join(output_dir, uniq_filename)
          FileUtils.mv(path, new_path)

          new_names << new_path
          original_names << path
        end
      end
    end

    # Loop through and remove directories
    dir_list.each do |item|
      if File.directory?(item)
        logger.info "removing a directory in safe_unzip"
        FileUtils.rm_rf(item)
      end
    end

    if squash
      # returns file list with absolute paths and original names
      return [new_names, original_names]
    else
      # returns file list with absolute paths
      return dir_list
    end
  end

end
