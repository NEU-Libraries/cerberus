class ProcessZipJob
  attr_accessor :loader_name, :zip_path, :parent, :copyright, :current_user, :permissions, :client, :derivatives

  def queue_name
    :loader_process_zip
  end

  def initialize(loader_name, zip_path, parent, copyright, current_user, permissions, derivatives=false, client=nil)
    self.loader_name = loader_name
    self.zip_path = zip_path
    self.parent = parent
    self.copyright = copyright
    self.current_user = current_user
    self.permissions = permissions
    self.derivatives = derivatives
    self.client = client
  end

  def run
    report_id = Loaders::LoadReport.create_from_strings(current_user, 0, loader_name, parent)
    load_report = Loaders::LoadReport.find(report_id)
    # unzip zip file to tmp storage
    unzip(zip_path, load_report, derivatives, client)
  end

  def unzip(file, load_report, derivatives=false, client)
    Zip::Archive.open(file) do |zipfile|
      to = File.join(File.dirname(file), File.basename(file, ".*"))
      FileUtils.mkdir(to) unless File.exists? to
      count = 0
      zipfile.each do |f|
        if !f.directory? && File.basename(f.name)[0] != "." # Don't extract directories or mac specific files
          file_name = File.basename(f.name)
          uniq_hsh = Digest::MD5.hexdigest("#{f.name}")[0,2]
          fpath = File.join(to, "#{Time.now.to_f.to_s.gsub!('.','-')}-#{uniq_hsh}") # Names file time and hash string
          open(fpath, 'wb') do |z|
            z << f.read
          end
          ImageProcessingJob.new(fpath, file_name, parent, copyright, load_report.id, permissions, derivatives, client).run
          load_report.update_counts
          count = count + 1
          load_report.save!
        end
      end
      load_report.number_of_files = count
      if load_report.success_count + load_report.fail_count + load_report.modified_count == load_report.number_of_files
        LoaderMailer.load_alert(load_report, User.find_by_nuid(load_report.nuid)).deliver!
        FileUtils.rmdir(to)
      end
      load_report.save!
    end
    FileUtils.rm(file)
  end
end
