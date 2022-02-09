class ExportModsJob
  attr_accessor :sess_id, :pid, :nuid, :user, :path

  def initialize(sess_id, pid, nuid)
    self.sess_id = sess_id
    self.pid = pid
    self.nuid = nuid
  end

  def queue_name
    :export_mods
  end

  def run
    self.user = !nuid.blank? ? User.find_by_nuid(nuid) : nil
    self.path = "#{Rails.application.config.tmp_path}/mods/#{sess_id}-#{pid.split(":").last}"

    FileUtils.rm_rf(Dir.glob("#{path}/*")) if File.directory?(path)
    FileUtils.mkdir_p path

    temp_path = "#{path}/in_progress.zip"
    full_path = "#{path}/mods_export.zip"
    temp_txt = "#{sess_id}.txt"

    # Kludge to avoid putting all zip items into memory
    Zip::File.open(temp_path, Zip::File::CREATE) do |zipfile|
      zipfile.get_output_stream(temp_txt) { |f| f.puts "" }
    end

    pids = SolrDocument.new(ActiveFedora::Base.find(pid, cast: true).to_solr).all_descendent_pids

    # Make spreadsheet
    Axlsx::Package.new do |x|
      x.workbook.add_worksheet(:name => "work sheet") do |sheet|
        sheet.add_row ["PIDs", "Original Filenames", "MODS XML File Path"]

        pids.each do |pid|
          if !ActiveFedora::SolrService.query("id:\"#{pid}\"").blank?
            mods_on_disk = fedora_versioned_path(pid, "mods")

            Zip::File.open(temp_path) do |zipfile|
              zipfile.add("neu-#{pid.split(":").last}-MODS.xml", mods_on_disk)
            end

            sheet.add_row ["#{pid}", "#{disk_original_filename(pid)}", "neu-#{pid.split(":").last}-MODS.xml"]
          end
        end

      end
      x.serialize("#{path}/manifest.xlsx")

      Zip::File.open(temp_path) do |zipfile|
        zipfile.add("manifest.xlsx", "#{path}/manifest.xlsx")
      end
    end

    # Remove temp txt file
    Zip::File.open(temp_path) do |zipfile|
      zipfile.remove(temp_txt)
    end

    # Rename temp path to full path so download can pick it up
    FileUtils.mv(temp_path, full_path)

    # Email user their download link
    ModsMailer.export_alert(self.pid ,self.nuid, self.sess_id).deliver!
  end

  def fedora_versioned_path(pid, datastream_type)
    # Get MODS fedora file path
    config_path = Rails.application.config.fedora_home

    latest_version = ""
    version = 0

    loop do
      datastream_str = "info:fedora/#{pid}/#{datastream_type}/#{datastream_type}.#{version}"
      escaped_datastream = Rack::Utils.escape(datastream_str)
      md5_str = Digest::MD5.hexdigest(datastream_str)
      dir_name = md5_str[0,2]
      file_path = config_path + dir_name + "/" + escaped_datastream

      if File.exist?(file_path)
        latest_version = file_path
        version += 1
      else
        return latest_version
      end
    end
  end

  def disk_original_filename(pid)
    properties_path = fedora_versioned_path(pid, "properties")
    x = CoreFile.new
    x.properties.content = File.read(properties_path).to_s
    return x.original_filename
  end
end
