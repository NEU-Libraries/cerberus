class MultipageCreateZipJob
  attr_accessor :dir_path, :core_file_pid, :zip_files

  def queue_name
    :multipage_create_zip
  end

  def initialize(dir_path, core_file_pid, zip_files)
    self.dir_path = dir_path
    self.core_file_pid = core_file_pid
    self.zip_files = zip_files
  end

  def run
    core_file = CoreFile.find(self.core_file_pid) || nil

    if core_file.blank?
      return
    end

    if !self.zip_files.blank?
      z = File.basename(Time.now.to_f.to_s.gsub!('.','-'), ".*") + ".zip"
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
      zipfile_name = tempdir.join(z).to_s

      temp_txt = "#{core_file.pid.gsub(":", "_")}.txt"

      # Kludge to avoid putting all zip items into memory
      Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
        zipfile.get_output_stream(temp_txt) { |f| f.puts "" }
      end

      zip_files.each do |f|
        full_path = self.dir_path + "/" + f
        Zip::File.open(zipfile_name) do |zipfile|
          zipfile.add(f, full_path)
        end
      end

      # Add zip to core_file
      zf = ZipFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
      zf.depositor              = core_file.depositor
      zf.core_record            = core_file
      zf.rightsMetadata.content = core_file.rightsMetadata.content
      zf.save!

      File.open(zipfile_name) do |file_contents|
        zf.add_file(file_contents, 'content', "page_items.zip")
        zf.save!
      end

      if !core_file.blank?
        core_file.tag_as_completed
        core_file.save!
      end

      # Cleanup
      FileUtils.rm_rf zipfile_name
    end
  end
end
