class ProcessMultipageZipJob
  attr_accessor :loader_name, :zip_path, :parent, :copyright, :current_user, :permissions, :client

  def queue_name
    :multipage_process_zip
  end

  def initialize(loader_name, zip_path, parent, copyright, current_user, permissions, client=nil)
    self.loader_name = loader_name
    self.zip_path = zip_path
    self.parent = parent
    self.copyright = copyright
    self.current_user = current_user
    self.permissions = permissions
    self.client = client
  end

  def run
    report_id = Loaders::LoadReport.create_from_strings(current_user, 0, loader_name, parent)
    load_report = Loaders::LoadReport.find(report_id)
    # unzip zip file to tmp storage
    unzip(zip_path, load_report, client)
  end

  def unzip(file, load_report, client)
    Zip::File.open(file) do |zipfile|
      to = File.join(File.dirname(file), File.basename(file, ".*"))
      FileUtils.mkdir(to) unless File.exists? to
      count = 0

      # Extract all files
      zipfile.each do |f|
        if !f.directory? && File.basename(f.name)[0] != "." # Don't extract directories or mac specific files
          fpath = File.join(to, f.name)
          FileUtils.mkdir_p(File.dirname(fpath))
          zipfile.extract(f, fpath) unless File.exist?(fpath)
        end
      end

      # Find the spreadsheet
      

    end
    FileUtils.rm(file)
  end
end
