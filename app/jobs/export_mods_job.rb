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
        sheet.add_row ["PIDs", "MODS XML File Path"]

        pids.each do |pid|
          if ActiveFedora::Base.exists?(pid)
            item = ActiveFedora::Base.find(pid, cast: true)

            # Make temp XML file
            File.write("#{path}/#{pid.split(":").last}-MODS.xml", item.mods.content)

            Zip::File.open(temp_path) do |zipfile|
              zipfile.add("neu-#{pid.split(":").last}-MODS.xml", "#{path}/#{pid.split(":").last}-MODS.xml")
            end

            sheet.add_row ["#{pid}", "neu-#{pid.split(":").last}-MODS.xml"]

            FileUtils.rm("#{path}/#{pid.split(":").last}-MODS.xml")
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
end
